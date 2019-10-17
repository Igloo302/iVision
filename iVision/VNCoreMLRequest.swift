/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Contains the object recognition view controller for the Breakfast Finder.
*/

import UIKit
import AVFoundation
import Vision

// 这是一个ViewController的子类
class VisionObjectRecognitionViewController: ViewController {
    
//    private var detectionOverlay: CALayer! = nil
//
//    // Vision parts
//    private var requests = [VNRequest]()
//
//    @discardableResult
//    func setupVision() -> NSError? {
//        // Setup Vision parts
//        let error: NSError! = nil
//
//        guard let modelURL = Bundle.main.url(forResource: "YOLOv3", withExtension: "mlmodelc") else {
//            return NSError(domain: "VisionObjectRecognitionViewController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model file is missing"])
//        }
//        do {
//            // 载入模型
//            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
//            print("UIView所需模型载入成功")
//            // 使用该模型创建一个VNCoreMLRequest，识别到之后执行completionHandler里面的部分
//            let objectRecognition = VNCoreMLRequest(model: visionModel, completionHandler: { (request, error) in
//                DispatchQueue.main.async(execute: {
//                    // perform all the UI updates on the main queue
//                    if let results = request.results {
//                        // 把结果在屏幕上呈现出来
//                        self.drawVisionRequestResults(results)
//                    }
//                })
//            })
//            self.requests = [objectRecognition]
//        } catch let error as NSError {
//            print("Model loading went wrong: \(error)")
//        }
//
//        return error
//    }
//
//    // 解析识别的对象观察
//    // 结果属性是观察值的数组，每个观察值都有一组标签和边界框
//    func drawVisionRequestResults(_ results: [Any]) {
//        CATransaction.begin()
//        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
//        detectionOverlay.sublayers = nil // remove all the old recognized objects
//        // 通过遍历数组来解析这些观察结果
//        for observation in results where observation is VNRecognizedObjectObservation {
//            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
//                continue
//            }
//            // Select only the label with the highest confidence.
//            // 标签数组列出每个分类标识符及其置信度值，从最高置信度到最低置信度排序。该示例应用程序仅在元素0处记录了具有最高置信度得分的分类。然后，它会在文本叠加层中显示此分类和置信度。
//            let topLabelObservation = objectObservation.labels[0]
//            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
//
//            let shapeLayer = self.createRoundedRectLayerWithBounds(objectBounds)
//
//            let textLayer = self.createTextSubLayerInBounds(objectBounds,
//                                                            identifier: topLabelObservation.identifier,
//                                                            confidence: topLabelObservation.confidence)
//            shapeLayer.addSublayer(textLayer)
//            detectionOverlay.addSublayer(shapeLayer)
//        }
//        self.updateLayerGeometry()
//        CATransaction.commit()
//    }
//
//
//    // captureOutPut的功能是Notifies the delegate that a new video frame was written.也就是每当有新的frame出现的时候就会调用分类器
//    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
//            return
//        }
//
//        let exifOrientation = exifOrientationFromDeviceOrientation()
//
//        // 把画面从CVImageBuffer变成了VNImageRequestHandler以供分类器执行分类
//        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
//        // Run Image Request
//        do {
//            try imageRequestHandler.perform(self.requests)
//        } catch {
//            print(error)
//        }
//    }
//
//    override func setupAVCapture() {
//        // 我理解的意思是？父类里面的setupAVCapture方法（显示画面）依旧执行一遍
//        super.setupAVCapture()
//
//        // setup Vision parts
//        setupLayers()
//        updateLayerGeometry()
//        setupVision()
//
//        // start the capture
//        startCaptureSession()
//    }
//
//    func setupLayers() {
//        detectionOverlay = CALayer() // container layer that has all the renderings of the observations
//        detectionOverlay.name = "DetectionOverlay"
//        detectionOverlay.bounds = CGRect(x: 0.0,
//                                         y: 0.0,
//                                         width: bufferSize.width,
//                                         height: bufferSize.height)
//        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
//        rootLayer.addSublayer(detectionOverlay)
//    }
//
//    func updateLayerGeometry() {
//        let bounds = rootLayer.bounds
//        var scale: CGFloat
//
//        let xScale: CGFloat = bounds.size.width / bufferSize.height
//        let yScale: CGFloat = bounds.size.height / bufferSize.width
//
//        scale = fmax(xScale, yScale)
//        if scale.isInfinite {
//            scale = 1.0
//        }
//        CATransaction.begin()
//        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
//
//        // rotate the layer into screen orientation and scale and mirror
//        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
//        // center the layer
//        detectionOverlay.position = CGPoint (x: bounds.midX, y: bounds.midY)
//
//        CATransaction.commit()
//
//    }
//
//    func createTextSubLayerInBounds(_ bounds: CGRect, identifier: String, confidence: VNConfidence) -> CATextLayer {
//        let textLayer = CATextLayer()
//        textLayer.name = "Object Label"
//        let formattedString = NSMutableAttributedString(string: String(format: "\(identifier)\nConfidence:  %.2f", confidence))
//        let largeFont = UIFont(name: "Helvetica", size: 24.0)!
//        formattedString.addAttributes([NSAttributedString.Key.font: largeFont], range: NSRange(location: 0, length: identifier.count))
//        textLayer.string = formattedString
//        textLayer.bounds = CGRect(x: 0, y: 0, width: bounds.size.height - 10, height: bounds.size.width - 10)
//        textLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
//        textLayer.shadowOpacity = 0.7
//        textLayer.shadowOffset = CGSize(width: 2, height: 2)
//        textLayer.foregroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.0, 0.0, 0.0, 1.0])
//        textLayer.contentsScale = 2.0 // retina rendering
//        // rotate the layer into screen orientation and scale and mirror
//        textLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: 1.0, y: -1.0))
//        return textLayer
//    }
//
//    func createRoundedRectLayerWithBounds(_ bounds: CGRect) -> CALayer {
//        let shapeLayer = CALayer()
//        shapeLayer.bounds = bounds
//        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
//        shapeLayer.name = "Found Object"
//        shapeLayer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1.0, 1.0, 0.2, 0.4])
//        shapeLayer.cornerRadius = 7
//        return shapeLayer
//    }
    
}
