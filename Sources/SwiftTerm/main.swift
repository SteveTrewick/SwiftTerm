import Foundation
import IOKit
import IOKit.serial
import Darwin

struct SerialConfiguration {
    var path: String
    var baudRate: Int
    var parity: Parity
    var dataBits: Int
    var stopBits: Int
}

enum Parity: String {
    case none
    case even
    case odd

    init?(argument: String) {
        switch argument.lowercased() {
        case "none", "n":
            self = .none
        case "even", "e":
            self = .even
        case "odd", "o":
            self = .odd
        default:
            return nil
        }
    }
}

enum Command {
    case list
    case connect(SerialConfiguration)
}

struct ArgumentParser {
    func parse(arguments: [String]) -> Command? {
        var iterator = arguments.dropFirst().makeIterator()
        var shouldList = false
        var path: String?
        var baud = 9600
        var parity: Parity = .none
        var dataBits = 8
        var stopBits = 1

        while let arg = iterator.next() {
            switch arg {
            case "--list", "-l":
                shouldList = true
            case "--port", "-p":
                guard let value = iterator.next() else {
                    return nil
                }
                path = value
            case "--baud", "-b":
                guard let value = iterator.next(), let speed = Int(value) else {
                    return nil
                }
                baud = speed
            case "--parity", "-P":
                guard let value = iterator.next(), let parsed = Parity(argument: value) else {
                    return nil
                }
                parity = parsed
            case "--data-bits", "-d":
                guard let value = iterator.next(), let bits = Int(value) else {
                    return nil
                }
                dataBits = bits
            case "--stop-bits", "-s":
                guard let value = iterator.next(), let bits = Int(value) else {
                    return nil
                }
                stopBits = bits
            case "--help", "-h":
                ArgumentParser.printUsage()
                exit(EXIT_SUCCESS)
            default:
                return nil
            }
        }

        if shouldList {
            return .list
        }

        guard let path else {
            return nil
        }

        let configuration = SerialConfiguration(
            path: path,
            baudRate: baud,
            parity: parity,
            dataBits: dataBits,
            stopBits: stopBits
        )

        return .connect(configuration)
    }

    static func printUsage() {
        let message = """
        Usage: swiftterm [options]

        Options:
          -l, --list                   List available serial ports
          -p, --port <path>            Serial port device path (e.g. /dev/tty.usbserial)
          -b, --baud <speed>           Baud rate (default: 9600)
          -P, --parity <none|even|odd> Parity configuration (default: none)
          -d, --data-bits <5-8>        Number of data bits (default: 8)
          -s, --stop-bits <1|2>        Number of stop bits (default: 1)
          -h, --help                   Show this help message

        The default configuration is N81.

        Examples:
          swiftterm --list
          swiftterm --port /dev/tty.usbserial --baud 115200
        """
        print(message)
    }
}

func listSerialPorts() -> [(path: String, name: String?)] {
    guard let matchingDict = IOServiceMatching(kIOSerialBSDServiceValue) as NSMutableDictionary? else {
        return []
    }

    matchingDict[kIOSerialBSDTypeKey] = kIOSerialBSDAllTypes

    var iterator: io_iterator_t = 0
    let kernResult = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
    guard kernResult == KERN_SUCCESS else {
        return []
    }

    defer {
        IOObjectRelease(iterator)
    }

    var result: [(String, String?)] = []

    while case let service = IOIteratorNext(iterator), service != 0 {
        var path: String?
        var name: String?

        if let cfPath = IORegistryEntryCreateCFProperty(service, kIOCalloutDeviceKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
            path = cfPath
        }

        if let cfName = IORegistryEntryCreateCFProperty(service, kIOTTYDeviceKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
            name = cfName
        }

        if let path {
            result.append((path, name))
        }

        IOObjectRelease(service)
    }

    return result
}

func speedConstant(for baud: Int) -> speed_t? {
    switch baud {
    case 50: return speed_t(B50)
    case 75: return speed_t(B75)
    case 110: return speed_t(B110)
    case 134: return speed_t(B134)
    case 150: return speed_t(B150)
    case 200: return speed_t(B200)
    case 300: return speed_t(B300)
    case 600: return speed_t(B600)
    case 1200: return speed_t(B1200)
    case 1800: return speed_t(B1800)
    case 2400: return speed_t(B2400)
    case 4800: return speed_t(B4800)
    case 9600: return speed_t(B9600)
    case 19200: return speed_t(B19200)
    case 38400: return speed_t(B38400)
    case 57600: return speed_t(B57600)
    case 115200: return speed_t(B115200)
    case 230400: return speed_t(B230400)
    default:
        return nil
    }
}

func configurePort(fd: Int32, configuration: SerialConfiguration) throws {
    var options = termios()
    if tcgetattr(fd, &options) == -1 {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? POSIXError(.ENOTTY))
    }

    cfmakeraw(&options)

    guard let speed = speedConstant(for: configuration.baudRate) else {
        throw POSIXError(.EINVAL)
    }
    cfsetspeed(&options, speed)

    options.c_cflag &= ~tcflag_t(CSIZE)

    switch configuration.dataBits {
    case 5:
        options.c_cflag |= tcflag_t(CS5)
    case 6:
        options.c_cflag |= tcflag_t(CS6)
    case 7:
        options.c_cflag |= tcflag_t(CS7)
    case 8:
        options.c_cflag |= tcflag_t(CS8)
    default:
        throw POSIXError(.EINVAL)
    }

    switch configuration.parity {
    case .none:
        options.c_cflag &= ~tcflag_t(PARENB)
    case .even:
        options.c_cflag |= tcflag_t(PARENB)
        options.c_cflag &= ~tcflag_t(PARODD)
    case .odd:
        options.c_cflag |= tcflag_t(PARENB)
        options.c_cflag |= tcflag_t(PARODD)
    }

    switch configuration.stopBits {
    case 1:
        options.c_cflag &= ~tcflag_t(CSTOPB)
    case 2:
        options.c_cflag |= tcflag_t(CSTOPB)
    default:
        throw POSIXError(.EINVAL)
    }

    options.c_cflag |= tcflag_t(CREAD | CLOCAL)

    options.c_iflag = 0
    options.c_oflag = 0
    options.c_lflag = 0

    withUnsafeMutablePointer(to: &options.c_cc) {
        $0.withMemoryRebound(to: cc_t.self, capacity: Int(NCCS)) { pointer in
            pointer[Int(VMIN)] = 1
            pointer[Int(VTIME)] = 0
        }
    }

    if tcsetattr(fd, TCSANOW, &options) == -1 {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? POSIXError(.ENOTTY))
    }

    if tcflush(fd, TCIOFLUSH) == -1 {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? POSIXError(.EIO))
    }

    if ioctl(fd, TIOCEXCL) == -1 {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? POSIXError(.EACCES))
    }

    let currentFlags = fcntl(fd, F_GETFL)
    if currentFlags != -1 {
        _ = fcntl(fd, F_SETFL, currentFlags & ~O_NONBLOCK)
    }
}

func openSerialPort(configuration: SerialConfiguration) throws -> Int32 {
    let fd = open(configuration.path, O_RDWR | O_NOCTTY | O_NONBLOCK)
    if fd == -1 {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? POSIXError(.EIO))
    }

    do {
        try configurePort(fd: fd, configuration: configuration)
    } catch {
        close(fd)
        throw error
    }

    return fd
}

func runTerminal(with configuration: SerialConfiguration) {
    do {
        let serialFD = try openSerialPort(configuration: configuration)
        setvbuf(stdout, nil, _IONBF, 0)
        print("Connected to \(configuration.path) at \(configuration.baudRate) baud")

        let queue = DispatchQueue(label: "swiftterm.serial", qos: .userInitiated)
        let serialSource = DispatchSource.makeReadSource(fileDescriptor: serialFD, queue: queue)
        let stdinSource = DispatchSource.makeReadSource(fileDescriptor: STDIN_FILENO, queue: queue)
        var signalSource: DispatchSourceSignal?

        let shutdown: () -> Void = {
            serialSource.cancel()
            stdinSource.cancel()
            signalSource?.cancel()
            exit(EXIT_SUCCESS)
        }

        serialSource.setEventHandler {
            var buffer = [UInt8](repeating: 0, count: 1024)
            let bytesRead = buffer.withUnsafeMutableBytes { ptr -> ssize_t in
                guard let baseAddress = ptr.baseAddress else { return 0 }
                return read(serialFD, baseAddress, ptr.count)
            }

            if bytesRead > 0 {
                let data = Data(buffer.prefix(Int(bytesRead)))
                FileHandle.standardOutput.write(data)
            } else if bytesRead == 0 {
                print("\nConnection closed")
                shutdown()
            } else {
                if errno == EAGAIN || errno == EINTR {
                    return
                }
                shutdown()
            }
        }

        serialSource.setCancelHandler {
            close(serialFD)
        }

        stdinSource.setEventHandler {
            var buffer = [UInt8](repeating: 0, count: 1024)
            let bytesRead = buffer.withUnsafeMutableBytes { ptr -> ssize_t in
                guard let baseAddress = ptr.baseAddress else { return 0 }
                return read(STDIN_FILENO, baseAddress, ptr.count)
            }

            if bytesRead > 0 {
                var totalWritten = 0
                while totalWritten < Int(bytesRead) {
                    let wrote = buffer.withUnsafeBytes { ptr -> ssize_t in
                        guard let baseAddress = ptr.baseAddress else { return -1 }
                        let pointer = baseAddress.advanced(by: totalWritten)
                        return write(serialFD, pointer, Int(bytesRead) - totalWritten)
                    }

                    if wrote > 0 {
                        totalWritten += Int(wrote)
                    } else if wrote == -1 && (errno == EAGAIN || errno == EINTR) {
                        continue
                    } else {
                        shutdown()
                        return
                    }
                }
            } else if bytesRead == 0 {
                shutdown()
            } else {
                if errno == EAGAIN || errno == EINTR {
                    return
                }
                shutdown()
            }
        }

        signal(SIGINT, SIG_IGN)
        let createdSignalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: queue)
        createdSignalSource.setEventHandler {
            print("\nReceived interrupt, closing connection")
            shutdown()
        }
        createdSignalSource.resume()
        signalSource = createdSignalSource

        serialSource.resume()
        stdinSource.resume()

        dispatchMain()
    } catch let posixError as POSIXError {
        let code = posixError.errorCode.rawValue
        fputs("Error: POSIX \(code) - \(posixError.localizedDescription)\n", stderr)
        exit(EXIT_FAILURE)
    } catch {
        fputs("Error: \(error.localizedDescription)\n", stderr)
        exit(EXIT_FAILURE)
    }
}

func main() {
    let parser = ArgumentParser()
    guard let command = parser.parse(arguments: CommandLine.arguments) else {
        ArgumentParser.printUsage()
        exit(EXIT_FAILURE)
    }

    switch command {
    case .list:
        let ports = listSerialPorts()
        if ports.isEmpty {
            print("No serial ports found")
        } else {
            for (path, name) in ports {
                if let name {
                    print("\(path) - \(name)")
                } else {
                    print(path)
                }
            }
        }
    case .connect(let configuration):
        runTerminal(with: configuration)
    }
}

main()
