# SwiftTerm

SwiftTerm is a macOS 11+ command line serial terminal written in Swift 5. It can list available USB serial devices and connect to them with customizable line settings.

## Requirements

- macOS 11 or newer
- Swift 5.5 toolchain (or newer Swift 5 compiler)

## Building

```bash
swift build -c release
```

The executable will be available at `.build/release/swiftterm`.

## Usage

```bash
swiftterm [options]
```

### Options

- `-l, --list` – List available serial devices.
- `-p, --port <path>` – Serial device path (for example `/dev/tty.usbserial-1410`).
- `-b, --baud <speed>` – Baud rate (default `9600`).
- `-P, --parity <none|even|odd>` – Parity configuration (default `none`). Short aliases `n`, `e`, and `o` are also accepted.
- `-d, --data-bits <5-8>` – Number of data bits (default `8`).
- `-s, --stop-bits <1|2>` – Number of stop bits (default `1`).
- `-h, --help` – Print usage information.

The default configuration is **N81** (no parity, 8 data bits, 1 stop bit).

### Examples

List available serial interfaces:

```bash
swiftterm --list
```

Open a USB serial adapter at 115200 baud:

```bash
swiftterm --port /dev/tty.usbserial-1410 --baud 115200
```

Quit the terminal session with `Ctrl+C` or by closing the device.
