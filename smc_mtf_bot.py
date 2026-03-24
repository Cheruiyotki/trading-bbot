"""
Multi-timeframe Smart Money Concepts bot for MetaTrader 5.

Timeframe model:
- 4H: directional bias (BOS/structure context)
- 1H: premium/discount + order-block zone selection
- 15m: entry trigger (micro BOS / CHoCH-style break)

Signals are computed from closed candles only to reduce repainting.
Default mode is dry-run (no live orders). Use --live to enable execution.
"""

from __future__ import annotations

import argparse
import logging
import logging.handlers
import time
from dataclasses import dataclass
from typing import Literal, Optional, Tuple

import MetaTrader5 as mt5
import numpy as np
import pandas as pd


Direction = Literal["bullish", "bearish"]
LOGGER = logging.getLogger("smc_mtf_bot")


@dataclass
class BotConfig:
    symbol: str = "EURUSD"
    risk_percent: float = 1.0
    rr_ratio: float = 1.8
    sl_buffer_pips: float = 3.0
    swing_length_h4: int = 10
    swing_length_h1: int = 8
    swing_length_m15: int = 4
    bars_h4: int = 500
    bars_h1: int = 700
    bars_m15: int = 1000
    ob_lookback_h1: int = 80
    displacement_atr_mult: float = 1.2
    max_spread_pips: float = 2.0
    one_position_only: bool = True
    check_interval_sec: int = 30
    magic: int = 460015
    live: bool = False
    use_break_even: bool = True
    enable_trailing: bool = True
    trailing_start_r: float = 1.2
    trailing_atr_mult: float = 1.0
    reconnect_wait_sec: int = 2
    login: int = 0
    password: str = ""
    server: str = ""


@dataclass
class Zone:
    direction: Direction
    top: float
    bottom: float
    source: str


@dataclass
class TradePlan:
    direction: Direction
    entry: float
    sl: float
    tp: float
    volume: float
    comment: str


def setup_logging(level: str, log_file: str) -> None:
    numeric_level = getattr(logging, level.upper(), logging.INFO)
    LOGGER.setLevel(numeric_level)
    LOGGER.handlers.clear()

    formatter = logging.Formatter(
        fmt="%(asctime)s | %(levelname)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    formatter.converter = time.gmtime

    console = logging.StreamHandler()
    console.setLevel(numeric_level)
    console.setFormatter(formatter)
    LOGGER.addHandler(console)

    rotating = logging.handlers.RotatingFileHandler(
        log_file,
        maxBytes=2_000_000,
        backupCount=3,
        encoding="utf-8",
    )
    rotating.setLevel(numeric_level)
    rotating.setFormatter(formatter)
    LOGGER.addHandler(rotating)


def tf_from_name(name: str) -> int:
    mapping = {
        "M15": mt5.TIMEFRAME_M15,
        "H1": mt5.TIMEFRAME_H1,
        "H4": mt5.TIMEFRAME_H4,
    }
    return mapping[name]


def fetch_rates(symbol: str, timeframe: int, count: int, closed_only: bool = False) -> pd.DataFrame:
    rates = mt5.copy_rates_from_pos(symbol, timeframe, 0, count)
    if rates is None or len(rates) == 0:
        raise RuntimeError(f"Failed to fetch rates for {symbol} tf={timeframe}")

    df = pd.DataFrame(rates)
    df["time"] = pd.to_datetime(df["time"], unit="s", utc=True)

    if closed_only:
        if len(df) < 2:
            raise RuntimeError(f"Not enough candles for closed-only fetch {symbol} tf={timeframe}")
        df = df.iloc[:-1].reset_index(drop=True)
    return df


def get_last_closed_bar_time(symbol: str, timeframe: int) -> Optional[pd.Timestamp]:
    df = fetch_rates(symbol, timeframe, 3, closed_only=False)
    if len(df) < 2:
        return None
    return df["time"].iloc[-2]


def true_range(df: pd.DataFrame) -> pd.Series:
    prev_close = df["close"].shift(1)
    tr = pd.concat(
        [
            df["high"] - df["low"],
            (df["high"] - prev_close).abs(),
            (df["low"] - prev_close).abs(),
        ],
        axis=1,
    ).max(axis=1)
    return tr


def atr(df: pd.DataFrame, period: int = 14) -> pd.Series:
    return true_range(df).rolling(period, min_periods=period).mean()


def pivot_highs(df: pd.DataFrame, left: int, right: int) -> pd.Series:
    out = pd.Series(False, index=df.index)
    for i in range(left, len(df) - right):
        center = df.at[i, "high"]
        if center >= df.loc[i - left : i - 1, "high"].max() and center >= df.loc[
            i + 1 : i + right, "high"
        ].max():
            out.iat[i] = True
    return out


def pivot_lows(df: pd.DataFrame, left: int, right: int) -> pd.Series:
    out = pd.Series(False, index=df.index)
    for i in range(left, len(df) - right):
        center = df.at[i, "low"]
        if center <= df.loc[i - left : i - 1, "low"].min() and center <= df.loc[
            i + 1 : i + right, "low"
        ].min():
            out.iat[i] = True
    return out


def last_pivot_levels(df: pd.DataFrame, length: int) -> Tuple[Optional[float], Optional[float]]:
    ph = pivot_highs(df, length, length)
    pl = pivot_lows(df, length, length)
    highs = df.loc[ph, "high"]
    lows = df.loc[pl, "low"]
    last_high = float(highs.iloc[-1]) if len(highs) else None
    last_low = float(lows.iloc[-1]) if len(lows) else None
    return last_high, last_low


def infer_h4_bias(df_h4: pd.DataFrame, swing_length: int) -> Optional[Direction]:
    last_high, last_low = last_pivot_levels(df_h4, swing_length)
    close = float(df_h4["close"].iloc[-1])

    if last_high is not None and close > last_high:
        return "bullish"
    if last_low is not None and close < last_low:
        return "bearish"

    ema_fast = df_h4["close"].ewm(span=20, adjust=False).mean().iloc[-1]
    ema_slow = df_h4["close"].ewm(span=50, adjust=False).mean().iloc[-1]
    if ema_fast > ema_slow:
        return "bullish"
    if ema_fast < ema_slow:
        return "bearish"
    return None


def find_h1_order_block(df_h1: pd.DataFrame, direction: Direction, lookback: int, atr_mult: float) -> Optional[Zone]:
    if len(df_h1) < lookback + 40:
        return None

    work = df_h1.copy()
    work["atr"] = atr(work)
    end = len(work) - 1
    start = max(20, end - lookback)
    if end - start < 7:
        return None

    # Confirm OB only when 6 future bars exist in closed-candle data.
    if direction == "bullish":
        for i in range(end - 7, start - 1, -1):
            is_bear_candle = work.at[i, "close"] < work.at[i, "open"]
            displacement = work.loc[i + 1 : i + 6, "high"].max() - work.at[i, "high"]
            atr_val = work.at[i, "atr"]
            if is_bear_candle and not np.isnan(atr_val) and displacement > atr_mult * atr_val:
                return Zone(
                    direction="bullish",
                    top=float(work.at[i, "high"]),
                    bottom=float(work.at[i, "low"]),
                    source="H1_OB_confirmed",
                )
    else:
        for i in range(end - 7, start - 1, -1):
            is_bull_candle = work.at[i, "close"] > work.at[i, "open"]
            displacement = work.at[i, "low"] - work.loc[i + 1 : i + 6, "low"].min()
            atr_val = work.at[i, "atr"]
            if is_bull_candle and not np.isnan(atr_val) and displacement > atr_mult * atr_val:
                return Zone(
                    direction="bearish",
                    top=float(work.at[i, "high"]),
                    bottom=float(work.at[i, "low"]),
                    source="H1_OB_confirmed",
                )
    return None


def fallback_h1_zone(df_h1: pd.DataFrame, direction: Direction, swing_length: int) -> Optional[Zone]:
    last_high, last_low = last_pivot_levels(df_h1, swing_length)
    if last_high is None or last_low is None:
        return None
    eq = (last_high + last_low) / 2.0
    if direction == "bullish":
        return Zone(direction="bullish", top=eq, bottom=last_low, source="H1_Discount")
    return Zone(direction="bearish", top=last_high, bottom=eq, source="H1_Premium")


def price_in_zone(price: float, zone: Zone) -> bool:
    lo, hi = min(zone.bottom, zone.top), max(zone.bottom, zone.top)
    return lo <= price <= hi


def micro_break_trigger(df_m15: pd.DataFrame, direction: Direction, swing_length: int) -> bool:
    if len(df_m15) < (swing_length * 4) + 10:
        return False
    ph = pivot_highs(df_m15, swing_length, swing_length)
    pl = pivot_lows(df_m15, swing_length, swing_length)
    highs = df_m15.loc[ph, "high"]
    lows = df_m15.loc[pl, "low"]
    if len(highs) < 1 or len(lows) < 1:
        return False
    last_high = float(highs.iloc[-1])
    last_low = float(lows.iloc[-1])
    close = float(df_m15["close"].iloc[-1])
    prev_close = float(df_m15["close"].iloc[-2])

    if direction == "bullish":
        return prev_close <= last_high and close > last_high
    return prev_close >= last_low and close < last_low


def pip_size(symbol_info: mt5.SymbolInfo) -> float:
    if symbol_info.digits in (3, 5):
        return symbol_info.point * 10.0
    return symbol_info.point


def normalize_volume(symbol_info: mt5.SymbolInfo, volume: float) -> float:
    step = symbol_info.volume_step
    vol_min = symbol_info.volume_min
    vol_max = symbol_info.volume_max
    clipped = max(min(volume, vol_max), vol_min)
    steps = np.floor(clipped / step)
    normalized = steps * step
    return float(round(normalized, 2))


def calc_volume(symbol: str, entry: float, sl: float, risk_percent: float) -> float:
    account = mt5.account_info()
    info = mt5.symbol_info(symbol)
    if account is None or info is None:
        raise RuntimeError("Missing account/symbol info for volume calculation")

    risk_amount = account.balance * (risk_percent / 100.0)
    tick_value = info.trade_tick_value
    tick_size = info.trade_tick_size
    if tick_value <= 0 or tick_size <= 0:
        raise RuntimeError("Invalid tick value/tick size")

    risk_price = abs(entry - sl)
    if risk_price <= 0:
        raise RuntimeError("Risk price must be > 0")

    value_per_price_per_lot = tick_value / tick_size
    risk_per_lot = risk_price * value_per_price_per_lot
    if risk_per_lot <= 0:
        raise RuntimeError("Risk per lot invalid")

    raw = risk_amount / risk_per_lot
    return normalize_volume(info, raw)


def current_spread_pips(symbol: str) -> float:
    tick = mt5.symbol_info_tick(symbol)
    info = mt5.symbol_info(symbol)
    if tick is None or info is None:
        return 999.0
    spread = tick.ask - tick.bid
    return spread / pip_size(info)


def build_trade_plan(cfg: BotConfig, direction: Direction, zone: Zone) -> Optional[TradePlan]:
    tick = mt5.symbol_info_tick(cfg.symbol)
    info = mt5.symbol_info(cfg.symbol)
    if tick is None or info is None:
        return None

    entry = float(tick.ask if direction == "bullish" else tick.bid)
    pips = pip_size(info)

    if direction == "bullish":
        sl = zone.bottom - (cfg.sl_buffer_pips * pips)
        risk = entry - sl
        if risk <= 0:
            return None
        tp = entry + (cfg.rr_ratio * risk)
    else:
        sl = zone.top + (cfg.sl_buffer_pips * pips)
        risk = sl - entry
        if risk <= 0:
            return None
        tp = entry - (cfg.rr_ratio * risk)

    vol = calc_volume(cfg.symbol, entry, sl, cfg.risk_percent)
    if vol <= 0:
        return None

    return TradePlan(
        direction=direction,
        entry=entry,
        sl=sl,
        tp=tp,
        volume=vol,
        comment=f"SMC_MTF_{direction.upper()}",
    )


def has_open_position(symbol: str, magic: int) -> bool:
    positions = mt5.positions_get(symbol=symbol)
    if positions is None:
        return False
    for p in positions:
        if int(p.magic) == magic:
            return True
    return False


def send_order(cfg: BotConfig, plan: TradePlan) -> bool:
    tick = mt5.symbol_info_tick(cfg.symbol)
    if tick is None:
        return False

    order_type = mt5.ORDER_TYPE_BUY if plan.direction == "bullish" else mt5.ORDER_TYPE_SELL
    price = tick.ask if plan.direction == "bullish" else tick.bid

    request = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": cfg.symbol,
        "volume": plan.volume,
        "type": order_type,
        "price": price,
        "sl": plan.sl,
        "tp": plan.tp,
        "deviation": 20,
        "magic": cfg.magic,
        "comment": plan.comment,
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_FOK,
    }

    result = mt5.order_send(request)
    if result is None:
        LOGGER.error("order_send returned None")
        return False
    ok = result.retcode == mt5.TRADE_RETCODE_DONE
    if ok:
        LOGGER.info("ORDER FILLED: ticket=%s dir=%s vol=%.2f", result.order, plan.direction, plan.volume)
    else:
        LOGGER.warning("ORDER FAILED: retcode=%s comment=%s", result.retcode, result.comment)
    return ok


def modify_position(cfg: BotConfig, ticket: int, sl: float, tp: float) -> bool:
    req = {
        "action": mt5.TRADE_ACTION_SLTP,
        "symbol": cfg.symbol,
        "position": ticket,
        "sl": sl,
        "tp": tp,
        "magic": cfg.magic,
    }
    res = mt5.order_send(req)
    return res is not None and res.retcode == mt5.TRADE_RETCODE_DONE


def latest_m15_atr(symbol: str, period: int = 14, bars: int = 240) -> Optional[float]:
    try:
        df = fetch_rates(symbol, tf_from_name("M15"), bars, closed_only=True)
    except Exception:
        return None
    series = atr(df, period=period).dropna()
    if len(series) == 0:
        return None
    return float(series.iloc[-1])


def manage_open_positions(cfg: BotConfig, trailing_atr: Optional[float]) -> None:
    positions = mt5.positions_get(symbol=cfg.symbol)
    if positions is None:
        return
    tick = mt5.symbol_info_tick(cfg.symbol)
    info = mt5.symbol_info(cfg.symbol)
    if tick is None or info is None:
        return

    point = info.point

    for p in positions:
        if int(p.magic) != cfg.magic:
            continue

        direction = "bullish" if p.type == mt5.POSITION_TYPE_BUY else "bearish"
        open_price = float(p.price_open)
        sl = float(p.sl) if p.sl else 0.0
        tp = float(p.tp) if p.tp else 0.0
        if sl <= 0:
            continue

        risk = (open_price - sl) if direction == "bullish" else (sl - open_price)
        if risk <= 0:
            continue

        current = float(tick.bid if direction == "bullish" else tick.ask)

        if cfg.use_break_even:
            hit_1r = (
                current >= (open_price + risk)
                if direction == "bullish"
                else current <= (open_price - risk)
            )
            already_be = abs(sl - open_price) <= (0.2 * point)
            if hit_1r and not already_be:
                if modify_position(cfg, p.ticket, open_price, tp):
                    LOGGER.info("Break-even moved for ticket %s", p.ticket)
                    sl = open_price

        if cfg.enable_trailing and trailing_atr is not None and trailing_atr > 0:
            profit = (current - open_price) if direction == "bullish" else (open_price - current)
            if profit >= cfg.trailing_start_r * risk:
                if direction == "bullish":
                    candidate = current - (cfg.trailing_atr_mult * trailing_atr)
                    candidate = min(candidate, current - (2 * point))
                    improved = candidate > sl + point
                else:
                    candidate = current + (cfg.trailing_atr_mult * trailing_atr)
                    candidate = max(candidate, current + (2 * point))
                    improved = candidate < sl - point

                if improved:
                    if modify_position(cfg, p.ticket, candidate, tp):
                        LOGGER.info("Trailing SL updated for ticket %s -> %.5f", p.ticket, candidate)


def compute_signal(cfg: BotConfig) -> Tuple[Optional[Direction], Optional[Zone], bool]:
    df_h4 = fetch_rates(cfg.symbol, tf_from_name("H4"), cfg.bars_h4, closed_only=True)
    df_h1 = fetch_rates(cfg.symbol, tf_from_name("H1"), cfg.bars_h1, closed_only=True)
    df_m15 = fetch_rates(cfg.symbol, tf_from_name("M15"), cfg.bars_m15, closed_only=True)

    bias = infer_h4_bias(df_h4, cfg.swing_length_h4)
    if bias is None:
        return None, None, False

    zone = find_h1_order_block(df_h1, bias, cfg.ob_lookback_h1, cfg.displacement_atr_mult)
    if zone is None:
        zone = fallback_h1_zone(df_h1, bias, cfg.swing_length_h1)
    if zone is None:
        return bias, None, False

    tick = mt5.symbol_info_tick(cfg.symbol)
    if tick is None:
        return bias, zone, False
    current_price = float(tick.bid if bias == "bullish" else tick.ask)

    in_zone = price_in_zone(current_price, zone)
    trigger = micro_break_trigger(df_m15, bias, cfg.swing_length_m15)
    return bias, zone, in_zone and trigger


def init_mt5_connection(symbol: str, login: int, password: str, server: str) -> bool:
    if not mt5.initialize():
        return False

    if login:
        if not mt5.login(login, password=password, server=server):
            return False

    info = mt5.symbol_info(symbol)
    if info is None:
        return False
    if not info.visible and not mt5.symbol_select(symbol, True):
        return False
    return True


def ensure_mt5_connection(cfg: BotConfig) -> bool:
    terminal = mt5.terminal_info()
    account = mt5.account_info()
    connected = terminal is not None and bool(getattr(terminal, "connected", False)) and account is not None
    if connected:
        return True

    LOGGER.warning("MT5 disconnected. Attempting reconnection...")
    mt5.shutdown()
    time.sleep(cfg.reconnect_wait_sec)

    ok = init_mt5_connection(cfg.symbol, cfg.login, cfg.password, cfg.server)
    if not ok:
        LOGGER.error("Reconnect attempt failed: %s", mt5.last_error())
        return False

    LOGGER.info("MT5 reconnected successfully.")
    return True


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="SMC Multi-Timeframe Bot (H4/H1/M15)")
    parser.add_argument("--symbol", default="EURUSD")
    parser.add_argument("--risk", type=float, default=1.0, help="Risk percent per trade")
    parser.add_argument("--rr", type=float, default=1.8, help="Reward-risk multiplier")
    parser.add_argument("--sl-buffer-pips", type=float, default=3.0)
    parser.add_argument("--max-spread", type=float, default=2.0, help="Max spread in pips")
    parser.add_argument("--magic", type=int, default=460015)
    parser.add_argument("--interval", type=int, default=30, help="Loop interval seconds")
    parser.add_argument("--live", action="store_true", help="Enable live order execution")
    parser.add_argument("--login", type=int, default=0, help="Optional MT5 account login")
    parser.add_argument("--password", default="", help="Optional MT5 account password")
    parser.add_argument("--server", default="", help="Optional MT5 server name")
    parser.add_argument("--no-break-even", action="store_true", help="Disable break-even logic")
    parser.add_argument("--no-trailing", action="store_true", help="Disable ATR trailing stop")
    parser.add_argument("--trail-start-r", type=float, default=1.2, help="Start trailing after this R")
    parser.add_argument("--trail-atr-mult", type=float, default=1.0, help="ATR multiplier for trailing stop")
    parser.add_argument("--log-level", default="INFO", help="DEBUG, INFO, WARNING, ERROR")
    parser.add_argument("--log-file", default="smc_mtf_bot.log", help="Log file path")
    return parser.parse_args()


def init_mt5(args: argparse.Namespace) -> None:
    if not init_mt5_connection(args.symbol, args.login, args.password, args.server):
        raise RuntimeError(f"MT5 initialize/login failed: {mt5.last_error()}")


def build_config(args: argparse.Namespace) -> BotConfig:
    return BotConfig(
        symbol=args.symbol,
        risk_percent=args.risk,
        rr_ratio=args.rr,
        sl_buffer_pips=args.sl_buffer_pips,
        max_spread_pips=args.max_spread,
        check_interval_sec=args.interval,
        magic=args.magic,
        live=args.live,
        use_break_even=not args.no_break_even,
        enable_trailing=not args.no_trailing,
        trailing_start_r=args.trail_start_r,
        trailing_atr_mult=args.trail_atr_mult,
        login=args.login,
        password=args.password,
        server=args.server,
    )


def run_loop(cfg: BotConfig) -> None:
    mode = "LIVE" if cfg.live else "DRY-RUN"
    LOGGER.info("Starting SMC MTF bot for %s mode=%s", cfg.symbol, mode)

    last_closed_m15: Optional[pd.Timestamp] = None

    while True:
        try:
            if not ensure_mt5_connection(cfg):
                time.sleep(cfg.check_interval_sec)
                continue

            trailing_val = latest_m15_atr(cfg.symbol)
            manage_open_positions(cfg, trailing_val)

            closed_time = get_last_closed_bar_time(cfg.symbol, tf_from_name("M15"))
            if closed_time is None:
                LOGGER.warning("No closed M15 bar available yet.")
                time.sleep(cfg.check_interval_sec)
                continue
            if last_closed_m15 is not None and closed_time == last_closed_m15:
                time.sleep(cfg.check_interval_sec)
                continue
            last_closed_m15 = closed_time

            spread = current_spread_pips(cfg.symbol)
            if spread > cfg.max_spread_pips:
                LOGGER.info("Skip: spread too high (%.2f pips)", spread)
                time.sleep(cfg.check_interval_sec)
                continue

            if cfg.one_position_only and has_open_position(cfg.symbol, cfg.magic):
                LOGGER.info("Skip: position already open")
                time.sleep(cfg.check_interval_sec)
                continue

            bias, zone, should_trade = compute_signal(cfg)
            if bias is None:
                LOGGER.info("No bias signal on H4")
                time.sleep(cfg.check_interval_sec)
                continue
            if zone is None:
                LOGGER.info("Bias=%s but no H1 zone found", bias)
                time.sleep(cfg.check_interval_sec)
                continue
            if not should_trade:
                LOGGER.info(
                    "No entry | bias=%s zone=[%.5f,%.5f] source=%s",
                    bias,
                    zone.bottom,
                    zone.top,
                    zone.source,
                )
                time.sleep(cfg.check_interval_sec)
                continue

            plan = build_trade_plan(cfg, bias, zone)
            if plan is None:
                LOGGER.warning("Signal found but trade plan invalid")
                time.sleep(cfg.check_interval_sec)
                continue

            LOGGER.info(
                "Signal %s | entry=%.5f sl=%.5f tp=%.5f vol=%.2f",
                plan.direction.upper(),
                plan.entry,
                plan.sl,
                plan.tp,
                plan.volume,
            )

            if cfg.live:
                send_order(cfg, plan)
            else:
                LOGGER.info("DRY-RUN: order not sent")

        except KeyboardInterrupt:
            LOGGER.info("Interrupted by user, stopping bot.")
            break
        except Exception:
            LOGGER.exception("Loop error")

        time.sleep(cfg.check_interval_sec)


def main() -> None:
    args = parse_args()
    setup_logging(args.log_level, args.log_file)
    try:
        init_mt5(args)
        cfg = build_config(args)
        run_loop(cfg)
    finally:
        mt5.shutdown()


if __name__ == "__main__":
    main()

