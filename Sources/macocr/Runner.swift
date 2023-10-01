//
//  Runner.swift
//  macocr
//
//  Created by Matthias Winkelmann on 13.01.22.
//
import Cocoa
import Vision
import Foundation

@available(macOS 15.0, *)
class Runner {


    struct ImageFileType {
        var uti: CFString
        var fileExtention: String

        // This list can include anything returned by CGImageDestinationCopyTypeIdentifiers()
        static let bmp = ImageFileType(uti: kUTTypeImage, fileExtention: "bmp")
        static let gif = ImageFileType(uti: kUTTypeImage, fileExtention: "gif")
        static let jpg = ImageFileType(uti: kUTTypeImage, fileExtention: "jpg")
        static let png = ImageFileType(uti: kUTTypeImage, fileExtention: "png")
        static let tiff = ImageFileType(uti: kUTTypeImage, fileExtention: "tiff")
        static let heic = ImageFileType(uti: kUTTypeImage, fileExtention: "heic")
    }

    func convertPDF(at sourceURL: URL, to destinationURL: URL, fileType: ImageFileType, dpi: CGFloat = 200) throws -> [URL] {
        let pdfDocument = CGPDFDocument(sourceURL as CFURL)!
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue

        var urls = [URL](repeating: URL(fileURLWithPath : "/"), count: pdfDocument.numberOfPages)
        DispatchQueue.concurrentPerform(iterations: pdfDocument.numberOfPages) { i in
            // Page number starts at 1, not 0
            let pdfPage = pdfDocument.page(at: i + 1)!

            let mediaBoxRect = pdfPage.getBoxRect(.mediaBox)
            let scale = dpi / 72.0
            let width = Int(mediaBoxRect.width * scale)
            let height = Int(mediaBoxRect.height * scale)

            let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo)!
            context.interpolationQuality = .high
            context.setFillColor(.white)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.scaleBy(x: scale, y: scale)
            context.drawPDFPage(pdfPage)

            let image = context.makeImage()!
            let imageName = sourceURL.deletingPathExtension().lastPathComponent
            let imageURL = destinationURL.appendingPathComponent("\(imageName)-Page\(i+1).\(fileType.fileExtention)")

            let imageDestination = CGImageDestinationCreateWithURL(imageURL as CFURL, fileType.uti, 1, nil)!
            CGImageDestinationAddImage(imageDestination, image, nil)
            CGImageDestinationFinalize(imageDestination)

            urls[i] = imageURL
        }
        return urls
    }


static func run(files: [String]) -> Int32 {

    // Flag ideas:
    // --version
    // Print REVISION
    // --langs
    //guard let langs = VNRecognizeTextRequest.supportedRecognitionLanguages(for: .accurate, revision: REVISION)
    // --fast (default accurate)
    // --fix (default no language correction)
    let urls = files.map {
        URL(fileURLWithPath: $0)
    }

    for url in urls {

        let img = NSImage(byReferencing: url)
        guard let imgRef = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            fputs("Error: failed to convert NSImage to CGImage for '\(url)'\n", stderr)
            return 1
        }

        let request = VNRecognizeTextRequest { (request, error) in
            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            let obs : [String] = observations.map { $0.topCandidates(1).first?.string ?? ""}
            try? obs.joined(separator: "\n").write(to: url.appendingPathExtension("md"), atomically: true, encoding: String.Encoding.utf8)

            fputs("got page obs is \(obs)", stderr)
        }
        request.recognitionLevel = VNRequestTextRecognitionLevel.accurate // or .fast
        request.usesLanguageCorrection = true
        request.revision = VNRecognizeTextRequestRevision3
        request.recognitionLanguages = ["de", "en"]
//        request.customWords = ["more", "Worte", "Wort"]

        try? VNImageRequestHandler(cgImage: imgRef, options: [:]).perform([request])
    }
    return 0
}
}
