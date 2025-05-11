import Foundation

class LibRawWrapper {
//    private var rawProcessor: OpaquePointer?
//    
//    init() {
//        rawProcessor = libraw_init(0)
//    }
//    
//    deinit {
//        if let processor = rawProcessor {
//            libraw_close(processor)
//        }
//    }
//    
    func loadRawFile(_ url: URL) -> (buffer: UnsafeMutablePointer<UInt8>?, width: Int, height: Int)? {
//        guard let processor = rawProcessor else { return nil }
//        
//        let path = url.path
//        var result = libraw_open_file(processor, path)
//        guard result == 0 else { return nil }
//        
//        result = libraw_unpack(processor)
//        guard result == 0 else { return nil }
//        
//        result = libraw_dcraw_process(processor)
//        guard result == 0 else { return nil }
//        
//        let width = Int(libraw_get_raw_width(processor))
//        let height = Int(libraw_get_raw_height(processor))
//        
//        var errcode: Int32 = 0
//        let image = libraw_dcraw_make_mem_image(processor, &errcode)
//        guard errcode == 0, let imageBuffer = image else { return nil }
//        
//        return (UnsafeMutablePointer<UInt8>(OpaquePointer(imageBuffer.pointee.data)), width, height)
        return nil
    }
} 
