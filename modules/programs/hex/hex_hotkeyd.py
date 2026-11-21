from __future__ import annotations

import argparse
from dataclasses import dataclass
from enum import Enum
import os
import queue
import selectors
import signal
import subprocess
import sys
import threading
import time
from typing import Any


class State(Enum):
    IDLE = "idle"
    PENDING_HOLD = "pending_hold"
    HOLDING = "holding"
    AWAITING_DOUBLE_TAP = "awaiting_double_tap"
    DOUBLE_TAP_DOWN = "double_tap_down"
    LOCKED = "locked"
    LOCKED_TRIGGER_DOWN = "locked_trigger_down"
    CHORDED = "chorded"
    LOCKED_CHORDED = "locked_chorded"


class Action(Enum):
    START = "start"
    STOP = "stop"
    CANCEL = "cancel"


@dataclass(frozen=True)
class HotkeyConfig:
    hold_ms: int = 250
    double_tap_ms: int = 350
    trigger_code: int = 125
    cancel_code: int = 1


class HotkeyMachine:
    def __init__(self, config: HotkeyConfig | None = None) -> None:
        self.config = config or HotkeyConfig()
        self.state: State = State.IDLE
        self.deadline_ms: int | None = None
        self.other_keys: set[tuple[int, int]] = set()
        self.trigger_devices: set[int] = set()

    def on_key(self, device_id: int, code: int, value: int, now_ms: int) -> list[Action]:
        if value not in (0, 1):
            return []

        actions = self.on_timeout(now_ms)

        if code == self.config.trigger_code:
            if value == 1:
                was_empty = not self.trigger_devices
                self.trigger_devices.add(device_id)
                if was_empty:
                    actions.extend(self._on_trigger_down(now_ms))
            else:
                if device_id in self.trigger_devices:
                    self.trigger_devices.remove(device_id)
                    if not self.trigger_devices:
                        actions.extend(self._on_trigger_up(now_ms))
            return actions

        if value == 1:
            self.other_keys.add((device_id, code))
            actions.extend(self._on_other_key_down(code))
        else:
            self.other_keys.discard((device_id, code))
        return actions

    def on_timeout(self, now_ms: int) -> list[Action]:
        if self.deadline_ms is None or now_ms < self.deadline_ms:
            return []

        self.deadline_ms = None
        if self.state in (
            State.PENDING_HOLD,
            State.DOUBLE_TAP_DOWN,
            State.LOCKED_TRIGGER_DOWN,
        ):
            self.state = State.HOLDING
            return [Action.START]
        if self.state == State.AWAITING_DOUBLE_TAP:
            self.state = State.IDLE
            return []
        return []

    def on_device_removed(self, device_id: int, now_ms: int) -> list[Action]:
        actions = self.on_timeout(now_ms)
        self.other_keys = {k for k in self.other_keys if k[0] != device_id}
        if device_id in self.trigger_devices:
            self.trigger_devices.remove(device_id)
            if not self.trigger_devices:
                actions.extend(self._on_trigger_up(now_ms))
        return actions

    def _on_trigger_down(self, now_ms: int) -> list[Action]:
        if self.other_keys:
            self.deadline_ms = None
            if self.state == State.LOCKED:
                self.state = State.LOCKED_CHORDED
            else:
                self.state = State.CHORDED
            return []

        if self.state == State.IDLE:
            self.state = State.PENDING_HOLD
            self.deadline_ms = now_ms + self.config.hold_ms
        elif self.state == State.AWAITING_DOUBLE_TAP:
            self.state = State.DOUBLE_TAP_DOWN
            self.deadline_ms = now_ms + self.config.hold_ms
        elif self.state == State.LOCKED:
            self.state = State.LOCKED_TRIGGER_DOWN
            self.deadline_ms = now_ms + self.config.hold_ms
        return []

    def _on_trigger_up(self, now_ms: int) -> list[Action]:
        if self.state == State.PENDING_HOLD:
            self.state = State.AWAITING_DOUBLE_TAP
            self.deadline_ms = now_ms + self.config.double_tap_ms
            return []

        self.deadline_ms = None
        if self.state == State.HOLDING:
            self.state = State.IDLE
            return [Action.STOP]
        if self.state == State.DOUBLE_TAP_DOWN:
            self.state = State.LOCKED
            return [Action.START]
        if self.state == State.LOCKED_TRIGGER_DOWN:
            self.state = State.IDLE
            return [Action.STOP]
        if self.state == State.CHORDED:
            self.state = State.IDLE
            return []
        if self.state == State.LOCKED_CHORDED:
            self.state = State.LOCKED
            return []
        return []

    def _on_other_key_down(self, code: int) -> list[Action]:
        if code == self.config.cancel_code:
            if self.state == State.HOLDING:
                self.state = State.CHORDED
                self.deadline_ms = None
                return [Action.CANCEL]
            if self.state == State.LOCKED:
                self.state = State.IDLE
                self.deadline_ms = None
                return [Action.CANCEL]
            if self.state == State.LOCKED_TRIGGER_DOWN:
                self.state = State.CHORDED
                self.deadline_ms = None
                return [Action.CANCEL]
            if self.state in (State.PENDING_HOLD, State.DOUBLE_TAP_DOWN):
                self.state = State.CHORDED
                self.deadline_ms = None
                return []
            if self.state == State.AWAITING_DOUBLE_TAP:
                self.state = State.IDLE
                self.deadline_ms = None
                return []
            return []

        if self.state in (State.PENDING_HOLD, State.DOUBLE_TAP_DOWN):
            self.state = State.CHORDED
            self.deadline_ms = None
            return []
        if self.state == State.HOLDING:
            self.state = State.CHORDED
            self.deadline_ms = None
            return [Action.CANCEL]
        if self.state == State.AWAITING_DOUBLE_TAP:
            self.state = State.IDLE
            self.deadline_ms = None
            return []
        if self.state == State.LOCKED_TRIGGER_DOWN:
            self.state = State.LOCKED_CHORDED
            self.deadline_ms = None
            return []
        return []


class HexCommandRunner:
    def __init__(self, hex_bin: str = "hex", timeout_s: float = 5.0) -> None:
        self._hex_bin = hex_bin
        self._timeout_s = timeout_s
        self._queue: queue.Queue[Action | None] = queue.Queue()
        self._thread = threading.Thread(
            target=self._worker,
            name="hex-command-runner",
            daemon=True,
        )
        self._thread.start()

    def submit(self, action: Action) -> None:
        self._queue.put(action)

    def close(self, timeout_s: float = 2.0) -> None:
        self._queue.put(None)
        self._thread.join(timeout=timeout_s)

    def _worker(self) -> None:
        while True:
            action = self._queue.get()
            if action is None:
                return
            cmd = [self._hex_bin, "dictation", action.value]
            try:
                result = subprocess.run(
                    cmd,
                    timeout=self._timeout_s,
                    check=False,
                    capture_output=True,
                    text=True,
                )
            except (OSError, subprocess.SubprocessError) as exc:
                print(f"hex-hotkeyd: failed to run {cmd}: {exc}", file=sys.stderr, flush=True)
                continue
            if result.returncode != 0:
                detail = result.stderr.strip() or result.stdout.strip()
                msg = f"hex-hotkeyd: {cmd} exited with {result.returncode}"
                if detail:
                    msg = f"{msg}: {detail}"
                print(msg, file=sys.stderr, flush=True)


def _now_ms() -> int:
    return time.monotonic_ns() // 1_000_000


def run_evdev_loop(
    config: HotkeyConfig,
    runner: HexCommandRunner,
    rescan_ms: int = 2000,
) -> int:
    import evdev

    ev_key = evdev.ecodes.EV_KEY
    key_a = 30
    wanted_codes = {config.trigger_code, key_a, config.cancel_code}

    machine = HotkeyMachine(config)
    selector = selectors.DefaultSelector()
    devices: dict[str, tuple[int, Any]] = {}
    next_device_id = 1
    stop = False

    def handle_signal(_signum: int, _frame: Any) -> None:
        nonlocal stop
        stop = True

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    def dispatch(actions: list[Action]) -> None:
        for action in actions:
            runner.submit(action)

    def is_keyboard(dev: Any) -> bool:
        caps = dev.capabilities(verbose=False)
        keys = caps.get(ev_key, ())
        return any(code in wanted_codes for code in keys)

    def rescan() -> None:
        nonlocal next_device_id
        for path in evdev.list_devices():
            if path in devices:
                continue
            try:
                dev = evdev.InputDevice(path)
            except OSError:
                continue
            try:
                if not is_keyboard(dev):
                    dev.close()
                    continue
                os.set_blocking(dev.fd, False)
                dev_id = next_device_id
                next_device_id += 1
                selector.register(dev.fd, selectors.EVENT_READ, (path, dev_id, dev))
                devices[path] = (dev_id, dev)
                print(
                    f"hex-hotkeyd: watching {path} ({dev.name})",
                    file=sys.stderr,
                    flush=True,
                )
            except OSError:
                try:
                    dev.close()
                except OSError:
                    pass

    def remove_device(path: str, ts_ms: int) -> None:
        entry = devices.pop(path, None)
        if entry is None:
            return
        dev_id, dev = entry
        try:
            selector.unregister(dev.fd)
        except (KeyError, ValueError, OSError):
            pass
        try:
            dev.close()
        except OSError:
            pass
        print(f"hex-hotkeyd: removed {path}", file=sys.stderr, flush=True)
        dispatch(machine.on_device_removed(dev_id, ts_ms))

    try:
        rescan()
        next_rescan_ms = _now_ms() + rescan_ms

        while not stop:
            now = _now_ms()
            dispatch(machine.on_timeout(now))

            if now >= next_rescan_ms:
                rescan()
                next_rescan_ms = now + rescan_ms

            next_wakeup_ms = next_rescan_ms
            if machine.deadline_ms is not None and machine.deadline_ms < next_wakeup_ms:
                next_wakeup_ms = machine.deadline_ms

            timeout_s = max(0.0, (next_wakeup_ms - _now_ms()) / 1000.0)
            try:
                ready = selector.select(timeout=timeout_s)
            except InterruptedError:
                continue

            now = _now_ms()
            for key, _ in ready:
                path, dev_id, dev = key.data
                try:
                    for event in dev.read():
                        if event.type == ev_key:
                            dispatch(machine.on_key(dev_id, event.code, event.value, now))
                except BlockingIOError:
                    continue
                except OSError:
                    remove_device(path, now)
    finally:
        for _, dev in list(devices.values()):
            try:
                selector.unregister(dev.fd)
            except (KeyError, ValueError, OSError):
                pass
            try:
                dev.close()
            except OSError:
                pass
        devices.clear()
        selector.close()
        runner.close()

    return 0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Hex evdev hold and double-tap hotkey daemon")
    parser.add_argument("--hex-bin", default="hex")
    parser.add_argument("--hold-ms", type=int, default=250)
    parser.add_argument("--double-tap-ms", type=int, default=350)
    parser.add_argument("--trigger-code", type=int, default=125)
    parser.add_argument("--cancel-code", type=int, default=1)
    parser.add_argument("--rescan-ms", type=int, default=2000)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    config = HotkeyConfig(
        hold_ms=args.hold_ms,
        double_tap_ms=args.double_tap_ms,
        trigger_code=args.trigger_code,
        cancel_code=args.cancel_code,
    )
    runner = HexCommandRunner(hex_bin=args.hex_bin)
    return run_evdev_loop(config, runner, rescan_ms=args.rescan_ms)


if __name__ == "__main__":
    raise SystemExit(main())
