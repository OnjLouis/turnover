// SPDX-License-Identifier: GPL-3.0-or-later
// rmdataless: delete a tree that holds iCloud "dataless" items whose file-provider domain is detached, so that
// listing them hangs and rm says "Directory not empty". Materialisation of dataless files is switched off for this
// process (setiopolicy_np), ACLs are dropped, and every item is removed without ever asking the provider for its
// contents. Prints each failure with its reason. Written for a stuck Trash, 9 Oct 2026.
//   rmdataless <path> [...]
import Foundation
import Darwin

let r = setiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_PROCESS, IOPOL_MATERIALIZE_DATALESS_FILES_OFF)
if r != 0 { print("could not switch dataless materialisation off: \(String(cString: strerror(errno)))") }

var removed = 0, failed = 0
func err(_ what: String, _ path: String) { failed += 1; print("\(what) failed: \(path): \(String(cString: strerror(errno)))") }

func dropACL(_ path: String) { _ = acl_set_link_np(path, ACL_TYPE_EXTENDED, nil) ; _ = chflags(path, 0) }

func remove(_ path: String) {
    var st = stat()
    guard lstat(path, &st) == 0 else { err("stat", path); return }
    dropACL(path)
    if (st.st_mode & S_IFMT) == S_IFDIR {
        // Try to list; a dataless directory with materialisation off refuses (EDEADLK) or has no entries: then just rmdir it.
        if let dir = opendir(path) {
            var names: [String] = []
            while let e = readdir(dir) {
                let name = withUnsafePointer(to: &e.pointee.d_name) { $0.withMemoryRebound(to: CChar.self, capacity: 1024) { String(cString: $0) } }
                if name != "." && name != ".." { names.append(name) }
            }
            closedir(dir)
            for n in names { remove(path + "/" + n) }
        }
        if rmdir(path) == 0 { removed += 1 } else { err("rmdir", path) }
    } else {
        if unlink(path) == 0 { removed += 1 } else { err("unlink", path) }
    }
}

for p in CommandLine.arguments.dropFirst() { remove(p) }
print("removed \(removed), failed \(failed)")
