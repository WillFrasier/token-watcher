import Foundation
import CoreServices

final class FSEventWatcher {
    let onChange: ([URL]) -> Void
    private var streamRef: FSEventStreamRef?
    private var selfPtr: UnsafeMutableRawPointer?

    init(onChange: @escaping ([URL]) -> Void) {
        self.onChange = onChange
    }

    func start(watching url: URL) {
        let paths = [url.path] as CFArray
        let retained = Unmanaged.passRetained(self)
        selfPtr = retained.toOpaque()
        var ctx = FSEventStreamContext(
            version: 0, info: selfPtr,
            retain: nil, release: nil, copyDescription: nil
        )

        let cb: FSEventStreamCallback = { _, info, numEvents, eventPaths, eventFlags, _ in
            guard let info else { return }
            let watcher = Unmanaged<FSEventWatcher>.fromOpaque(info).takeUnretainedValue()
            let paths = unsafeBitCast(eventPaths, to: NSArray.self)
            let flags = UnsafeBufferPointer(start: eventFlags, count: numEvents)

            var urls: [URL] = []
            for i in 0..<numEvents {
                guard flags[i] & UInt32(kFSEventStreamEventFlagItemIsFile) != 0 else { continue }
                guard let path = paths[i] as? String else { continue }
                let u = URL(fileURLWithPath: path)
                guard u.pathExtension == "jsonl" else { continue }
                urls.append(u)
            }
            if !urls.isEmpty { watcher.onChange(urls) }
        }

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes
        )
        streamRef = FSEventStreamCreate(
            nil, cb, &ctx, paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5, flags
        )

        if let s = streamRef {
            FSEventStreamSetDispatchQueue(s, DispatchQueue.main)
            FSEventStreamStart(s)
        }
    }

    func stop() {
        if let s = streamRef {
            FSEventStreamStop(s)
            FSEventStreamInvalidate(s)
            FSEventStreamRelease(s)
            streamRef = nil
        }
        if let ptr = selfPtr {
            Unmanaged<FSEventWatcher>.fromOpaque(ptr).release()
            selfPtr = nil
        }
    }

    deinit { stop() }
}
