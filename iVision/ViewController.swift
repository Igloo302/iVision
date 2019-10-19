/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Contains the view controller for the Breakfast Finder.
*/

import UIKit
import AVFoundation
import Vision
import SceneKit
import ARKit

class ViewController: UIViewController,ARSCNViewDelegate,ARSessionDelegate {
    
    @IBOutlet weak var debugTextView: UITextView!
    @IBOutlet weak var sceneView: ARSCNView!
    
    // Disable this to see the energy impact of just running the neural net,
    // otherwise it also counts the GPU activity of drawing the bounding boxes.
    let drawBoundingBoxes = true

    // How many predictions we can do concurrently.
    static let maxInflightBuffers = 3
    
    let yolo = YOLO()
    
    // COREML
    var requests = [VNCoreMLRequest]()
    var visionRequests = [VNRequest]()
    
    //计时器
    var startTimes: [CFTimeInterval] = []
    
    var boundingBoxes = [BoundingBox]()
    var colors: [UIColor] = []
    
    // 估计可以删除
//    let ciContext = CIContext()
//    var resizedPixelBuffers: [CVPixelBuffer?] = []
    
    // 测FPS用
    var framesDone = 0
    var frameCapturingStartTime = CACurrentMediaTime()
    
    var inflightBuffer = 0
    let semaphore = DispatchSemaphore(value: ViewController.maxInflightBuffers)
    
    
    
    
    
    
    // 显示识别结果的Bounding的图层
    var detectionOverlay: CALayer! = nil
    var rootLayer: CALayer! = nil
    
    // 屏幕尺寸
    var bufferSize: CGSize = .zero
    
    let bubbleDepth : Float = 0.01 // the 'depth' of 3D text 文字的厚度
    
    // variable containing the latest CoreML prediction & position
    var latestPrediction : String = ""
    var latestPredictionPosition: CGPoint = .zero
    
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        sceneView.preferredFramesPerSecond = 30
        // Create a new scene
        let scene = SCNScene()
        // Set the scene to the view
        sceneView.scene = scene
        // Enable Default Lighting - makes the 3D text a bit poppier.
        sceneView.autoenablesDefaultLighting = true
        sceneView.debugOptions = [.showFeaturePoints]
        
        
        
//        bufferSize = CGSize(width: sceneView.bounds.height, height: sceneView.bounds.width)
//        print("😎把BufferSize设置成", bufferSize)
        
        //配置Layer初始化
//        rootLayer = sceneView.layer
//        setupLayers()
//        updateLayerGeometry()
        
        // Tap Gesture Recognizer 点击操作识别器
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)
        
//        // 设置YOLO识别器
//        // Vision classification request and model
//        guard let ARmodelURL = Bundle.main.url(forResource: "YOLOv3Tiny", withExtension: "mlmodelc") else {fatalError("没有找到YOLOv3模型，凉凉")
//        }
//        do {
//            // 载入模型
//            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: ARmodelURL))
//            print("😎SceneKit所需模型载入成功")
//            // 使用该模型创建一个VNCoreMLRequest，识别到之后执行completionHandler里面的部分
//            let ARobjectRecognition = VNCoreMLRequest(model: visionModel, completionHandler: objectRecognitionCompleteHandler)
//
//            // Crop input images to square area at center, matching the way the ML model was trained.
//
//            // NOTE: If you choose another crop/scale option, then you must also
//            // change how the BoundingBox objects get scaled when they are drawn.
//            // Currently they assume the full input image is used.
//            ARobjectRecognition.imageCropAndScaleOption = .scaleFill
//
//            // Use CPU for Vision processing to ensure that there are adequate GPU resources for rendering.
//            // ARobjectRecognition.usesCPUOnly = true
//
//            visionRequests = [ARobjectRecognition]
//        } catch let error as NSError {
//            print("Model loading went wrong: \(error)")
//        }
        
        

        setUpBoundingBoxes()
        print("setUpBoundingBoxes Done")
//        setUpCoreImage()
        setUpVision()
        print("setUpVision Done")
        
        // Add the bounding box layers to the UI, on top of the video preview.
        for box in boundingBoxes {
          box.addToLayer(sceneView.layer)
        }

        frameCapturingStartTime = CACurrentMediaTime()
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Enable plane detection
        // configuration.planeDetection = [.horizontal, .vertical]

        // Run the view's session
        sceneView.session.run(configuration)
        print("😎AR Configuration载入成功")
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    
    
    // MARK: - Initialization

    func setUpBoundingBoxes() {
      for _ in 0..<YOLO.maxBoundingBoxes {
        boundingBoxes.append(BoundingBox())
      }

      // Make colors for the bounding boxes. There is one color for each class,
      // 20 classes in total.
      for r: CGFloat in [0.2, 0.4, 0.6, 0.8, 1.0] {
        for g: CGFloat in [0.3, 0.7] {
          for b: CGFloat in [0.4, 0.8] {
            let color = UIColor(red: r, green: g, blue: b, alpha: 1)
            colors.append(color)
          }
        }
      }
    }

//    func setUpCoreImage() {
//      // Since we might be running several requests in parallel, we also need
//      // to do the resizing in different pixel buffers or we might overwrite a
//      // pixel buffer that's already in use.
//      // 由于我们可能并行运行多个请求
//      // 因此我们还需要在不同的像素缓冲区中进行大小调整
//      // 否则我们可能会覆盖已经在使用的像素缓冲区。
//      for _ in 0..<YOLO.maxBoundingBoxes {
//        var resizedPixelBuffer: CVPixelBuffer?
//        let status = CVPixelBufferCreate(nil, YOLO.inputWidth, YOLO.inputHeight,
//                                         kCVPixelFormatType_32BGRA, nil,
//                                         &resizedPixelBuffer)
//
//        if status != kCVReturnSuccess {
//          print("Error: could not create resized pixel buffer", status)
//        }
//        resizedPixelBuffers.append(resizedPixelBuffer)
//      }
//    }

    func setUpVision() {
      guard let visionModel = try? VNCoreMLModel(for: yolo.model.model) else {
        print("Error: could not create Vision model")
        return
      }

      for _ in 0..<ViewController.maxInflightBuffers {
        let request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)

        // NOTE: If you choose another crop/scale option, then you must also
        // change how the BoundingBox objects get scaled when they are drawn.
        // Currently they assume the full input image is used.
        request.imageCropAndScaleOption = .scaleFill
        requests.append(request)
      }
    }
    
      // MARK: - Doing inference
    
    func predict(image: UIImage) {
      if let pixelBuffer = image.pixelBuffer(width: YOLO.inputWidth, height: YOLO.inputHeight) {
        predictUsingVision(pixelBuffer: pixelBuffer, inflightIndex: 0)
      }
    }

      func predictUsingVision(pixelBuffer: CVPixelBuffer, inflightIndex: Int) {
        // Measure how long it takes to predict a single video frame. Note that
        // predict() can be called on the next frame while the previous one is
        // still being processed. Hence the need to queue up the start times.
        // 测量预测单个视频帧所需的时间
        // 请注意，可在下一帧仍在处理前一帧时在下一帧上调用predict（）
        // 因此，需要排队开始时间。
        startTimes.append(CACurrentMediaTime())
        

        // Vision will automatically resize the input image.
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        let request = requests[inflightIndex]

        // Because perform() will block until after the request completes, we
        // run it on a concurrent background queue, so that the next frame can
        // be scheduled in parallel with this one.
        // 因为perform（）将阻塞直到请求完成
        // 所以我们在并发后台队列上运行它
        // 以便可以与该帧并行调度下一帧。
        DispatchQueue.global().async {
          try? handler.perform([request])
        }
      }

      func visionRequestDidComplete(request: VNRequest, error: Error?) {
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
           let features = observations.first?.featureValue.multiArrayValue {

          let boundingBoxes = yolo.computeBoundingBoxes(features: features)
          let elapsed = CACurrentMediaTime() - startTimes.remove(at: 0)
          showOnMainThread(boundingBoxes, elapsed)
        } else {
          print("不妙")
        }

        self.semaphore.signal()
      }

      func showOnMainThread(_ boundingBoxes: [YOLO.Prediction], _ elapsed: CFTimeInterval) {
        if drawBoundingBoxes {
          DispatchQueue.main.async {
            // For debugging, to make sure the resized CVPixelBuffer is correct.
            //var debugImage: CGImage?
            //VTCreateCGImageFromCVPixelBuffer(resizedPixelBuffer, nil, &debugImage)
            //self.debugImageView.image = UIImage(cgImage: debugImage!)

            self.show(predictions: boundingBoxes)

            let fps = self.measureFPS()
            self.debugTextView.text = String(format:"Elapsed %.5f seconds - %.2f FPS", elapsed, fps)
          }
        }
      }

      func measureFPS() -> Double {
        // Measure how many frames were actually delivered per second.
        framesDone += 1
        let frameCapturingElapsed = CACurrentMediaTime() - frameCapturingStartTime
        let currentFPSDelivered = Double(framesDone) / frameCapturingElapsed
        if frameCapturingElapsed > 1 {
          framesDone = 0
          frameCapturingStartTime = CACurrentMediaTime()
        }
        return currentFPSDelivered
      }

      func show(predictions: [YOLO.Prediction]) {
        for i in 0..<boundingBoxes.count {
          if i < predictions.count {
            let prediction = predictions[i]

            // The predicted bounding box is in the coordinate space of the input
            // image, which is a square image of 416x416 pixels. We want to show it
            // on the video preview, which is as wide as the screen and has a 16:9
            // aspect ratio. The video preview also may be letterboxed at the top
            // and bottom.
            // 预测边界框在输入图像的坐标空间中
            // 该图像是416x416像素的正方形图像
            // 我们希望在与屏幕一样宽且具有16：9宽高比的视频预览中显示它
            // 视频预览的顶部和底部也可能带有黑框。
            
            // 此处代码有错误
            let width = view.bounds.width
            let height = view.bounds.height
            let scaleX = width / CGFloat(YOLO.inputWidth)
            let scaleY = height / CGFloat(YOLO.inputHeight)
            let top = (view.bounds.height - height) / 2
            print(width, height, scaleX, scaleY, top)
            

            // Translate and scale the rectangle to our own coordinate system.
            var rect = prediction.rect
            print(rect)
            rect.origin.x *= scaleX
            rect.origin.y *= scaleY
            rect.origin.y += top
            rect.size.width *= scaleX
            rect.size.height *= scaleY

            // Show the bounding box.
            // 显示框框
            let label = String(format: "%@ %.1f", labels[prediction.classIndex], prediction.score * 100)
            let color = colors[prediction.classIndex]
            boundingBoxes[i].show(frame: rect, label: label, color: color)
          } else {
            boundingBoxes[i].hide()
          }
        }
      }



    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    // MARK: - Status Bar: Hide
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    // MARK: - Interaction


    @objc func handleTap(gestureRecognize: UITapGestureRecognizer) {
        
        
        print("🌚TouchPoint", gestureRecognize.location(in: sceneView))
        let HitTestResults : [ARHitTestResult] = sceneView.hitTest(gestureRecognize.location(in: sceneView), types: [.featurePoint])
        
        if let closestResult = HitTestResults.first {
            // Get Coordinates of HitTest
            let transform : matrix_float4x4 = closestResult.worldTransform
            let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)

            // Create 3D Text
            let node : SCNNode = createNewBubbleParentNode(latestPrediction)
            sceneView.scene.rootNode.addChildNode(node)
            node.position = worldCoord
            print(worldCoord)
        }
    }
    

    func showNode() {
            // 真正的位置！
            // print("🌚latestPredictionPosition", latestPredictionPosition)
            let HitTestResults : [ARHitTestResult] = sceneView.hitTest(latestPredictionPosition, types: [.featurePoint])
            
            if let closestResult = HitTestResults.first {
                // Get Coordinates of HitTest
                let transform : matrix_float4x4 = closestResult.worldTransform
                let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)

                // Create 3D Text
                let node : SCNNode = createNewBubbleParentNode(latestPrediction)
                sceneView.scene.rootNode.addChildNode(node)
                node.position = worldCoord
            }
        }
    
    func createNewBubbleParentNode(_ text : String) -> SCNNode {
        // Warning: Creating 3D Text is susceptible to crashing. To reduce chances of crashing; reduce number of polygons, letters, smoothness, etc.
        let bubbleNodeParent = SCNNode()
        bubbleNodeParent.addChildNode(createBubbleNode(bubble: text))
        bubbleNodeParent.addChildNode(createSphereNode())
        bubbleNodeParent.constraints = [createBillboardConstraint()]
        return bubbleNodeParent
    }

    private func createBubbleNode(bubble: String) -> SCNNode {
        let bubble = createBubble(text: bubble)
//        // 让Siri说说话
//        var stringToSpeak = String("")
//        for _ in 0..<100 {
//            stringToSpeak += (bubble + "is here.")
//        }
//
//        let utterance = AVSpeechUtterance(string: stringToSpeak)
//        let synthesizer = AVSpeechSynthesizer()
//        synthesizer.speak(utterance)
//
//        let avMaterial = SCNMaterial()
//        avMaterial.diffuse.contents = synthesizer
//        bubble.materials = [avMaterial]
        let (minBound, maxBound) = bubble.boundingBox
        let bubbleNode = SCNNode(geometry: bubble)
        // Centre Node - to Centre-Bottom point
        bubbleNode.pivot = SCNMatrix4MakeTranslation( (maxBound.x - minBound.x)/2, minBound.y, bubbleDepth/2)
        // Reduce default text size
        bubbleNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
        
//        //播放音乐
//        let audioSource = SCNAudioSource(fileNamed: "Dog.mp3")!
//        // As an environmental sound layer, audio should play indefinitely
//        audioSource.loops = true
//        // Decode the audio from disk ahead of time to prevent a delay in playback
//        audioSource.load()
//
//        // Create a player from the source and add it to `objectNode`
//        bubbleNode.addAudioPlayer(SCNAudioPlayer(source: audioSource))
        
        return bubbleNode
    }

    private func createBubble(text: String) -> SCNText {
        let bubble = SCNText(string: text, extrusionDepth: CGFloat(bubbleDepth))
        var font = UIFont(name: "Futura", size: 0.15)
        font = font?.withTraits(traits: .traitBold)
        bubble.font = font
        bubble.alignmentMode = convertFromCATextLayerAlignmentMode(CATextLayerAlignmentMode.center)
        bubble.firstMaterial?.diffuse.contents = UIColor.orange
        bubble.firstMaterial?.specular.contents = UIColor.white
        bubble.firstMaterial?.isDoubleSided = true
        // bubble.flatness // setting this too low can cause crashes.
        bubble.chamferRadius = CGFloat(bubbleDepth)
        return bubble
    }

    private func createSphereNode() -> SCNNode {
        let sphere = SCNSphere(radius: 0.005)
        sphere.firstMaterial?.diffuse.contents = UIColor.cyan
        return SCNNode(geometry: sphere)
    }

    private func createBillboardConstraint() -> SCNBillboardConstraint {
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        return billboardConstraint
    }
    
    
    // MARK: - CoreML Vision Handling
    
    private let visionQueue = DispatchQueue(label: "com.example.apple-samplecode.ARKitVision.serialVisionQueue")
    // The pixel buffer being held for analysis; used to serialize Vision requests.
    private var pixbuff: CVPixelBuffer?
    
    // ✌️重要！把画面弄到core ML模型进行识别的部分！
    func updateCoreML() {
        // Get Camera Image as RGB SCENEVIEW的图片就用当前帧的画面弄出来就行
        pixbuff  = sceneView.session.currentFrame?.capturedImage
        if pixbuff == nil { return }
        
        // 计时器
        startTimes.append(CACurrentMediaTime())
        
        // Prepare CoreML/Vision Request，VNImageRequestHandler是处理与单个图像有关的一个或多个图像分析请求的对象
        // Vision will automatically resize the input image.
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixbuff!, options: [:])

        // Run Image Request
        visionQueue.async {
            do {
                // Release the pixel buffer when done, allowing the next buffer to be processed.
                defer { self.pixbuff = nil }
                // 识别器
                try imageRequestHandler.perform(self.visionRequests)
            } catch {
                print("Error: Vision request failed with error \"\(error)\"")
            }
        }
    }
    
    
    // 识别器完成之后干的事情
    // Handle completion of the Vision request and choose results to display.
    func objectRecognitionCompleteHandler(request: VNRequest, error: Error?){
        // Catch Errors
        guard let observations = request.results else {
            print("Unable to classify image.\n\(error!.localizedDescription)")
            return
        }
        
        // 输出模型延迟
        let elapsed = CACurrentMediaTime() - startTimes.remove(at: 0)
        print(String(format: "Elapsed %.5f seconds", elapsed))
    
        //CATransaction.begin()
        //CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionOverlay.sublayers = nil // remove all the old recognized objects
        
        // Get ObjectRecognition
        for observation in observations where observation is VNRecognizedObjectObservation{
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                continue
            }
            // Select only the label with the highest confidence.
            // 标签数组列出每个分类标识符及其置信度值，从最高置信度到最低置信度排序。
            // 该示例应用程序仅在元素0处记录了具有最高置信度得分的分类。
            // 然后，它会在文本叠加层中显示此分类和置信度。
            let topLabelObservation = objectObservation.labels[0]
            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
            
            DispatchQueue.main.async {
                var debugText:String = ""
                debugText += "\(topLabelObservation.identifier)" + "\(topLabelObservation.confidence)"
                self.debugTextView.text = debugText
                // print("😎", topLabelObservation.identifier)
                

                // 保存识别的结果
                self.latestPrediction = topLabelObservation.identifier
                self.latestPredictionPosition = CGPoint(x:objectBounds.midY, y: objectBounds.midX)
                
                // 显示Cube
                // self.showNode()
                
                //显示Layer
                let shapeLayer = self.createRoundedRectLayerWithBounds(objectBounds, identifier: topLabelObservation.identifier)
                let textLayer = self.createTextSubLayerInBounds(objectBounds, identifier: topLabelObservation.identifier, confidence: topLabelObservation.confidence)
                
                CATransaction.setDisableActions(true)
                shapeLayer.addSublayer(textLayer)
                self.detectionOverlay.addSublayer(shapeLayer)
                
//                for layer in self.detectionOverlay.sublayers!{
//                    if shapeLayer.name == layer.name{
//                        layer.removeFromSuperlayer()
//
//                    }
//                }
                
            }
            // self.updateLayerGeometry()
            // CATransaction.commit()
        }
    }
    
//        // 分类器识别出结果的时候会这样做：
//        func classificationCompleteHandler(request: VNRequest, error: Error?) {
//            // Catch Errors
//            if error != nil {
//                print("Error: " + (error?.localizedDescription)!)
//                return
//            }
//            guard let observations = request.results else {
//                print("No results")
//                return
//            }
//
//            // Get Classifications 分类的内容弄出来
//            let classifications = observations[0...1] // top 2 results
//                .compactMap({ $0 as? VNClassificationObservation })
//                .map({ "\($0.identifier) \(String(format:"- %.2f", $0.confidence))" })
//                .joined(separator: "\n")
//
//
//            DispatchQueue.main.async {
//                // Display Debug Text on screen
//                // 把识别结果先都显示在Debug里
//                var debugText:String = ""
//                debugText += classifications
//                self.debugTextView.text = debugText
//
//                // Store the latest prediction
//                // 存储最新的识别结果
//                var objectName:String = "…"
//                objectName = classifications.components(separatedBy: "-")[0]
//                objectName = objectName.components(separatedBy: ",")[0]
//                self.latestPrediction = objectName
//
//            }
//        }
    
    func setupLayers() {
        // container layer that has all the renderings of the observations
        detectionOverlay = CALayer()
        
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0.0,
                                         y: 0.0,
                                         width: bufferSize.width,
                                         height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        rootLayer.addSublayer(detectionOverlay)
    }
    
    func updateLayerGeometry() {
        let bounds = rootLayer.bounds
        var scale: CGFloat

        let xScale: CGFloat = bounds.size.width / bufferSize.height
        let yScale: CGFloat = bounds.size.height / bufferSize.width

        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)

        // rotate the layer into screen orientation and scale and mirror
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        // center the layer
        detectionOverlay.position = CGPoint (x: bounds.midX, y: bounds.midY)

        CATransaction.commit()

    }

    // MARK: - AR中创建Node相关
    
    func createTextSubLayerInBounds(_ bounds: CGRect, identifier: String, confidence: VNConfidence) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.name = "Object Label"
        let formattedString = NSMutableAttributedString(string: String(format: "\(identifier)\n%.2f", confidence))
        let largeFont = UIFont(name: "Helvetica", size: 12.0)!
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont], range: NSRange(location: 0, length: identifier.count))
        textLayer.string = formattedString
        textLayer.bounds = CGRect(x: 0, y: 0, width: bounds.size.height - 10, height: bounds.size.width - 10)
        textLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        textLayer.shadowOpacity = 0.7
        textLayer.shadowOffset = CGSize(width: 2, height: 2)
        textLayer.foregroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.0, 0.0, 0.0, 1.0])
        textLayer.contentsScale = 2.0 // retina rendering
        // rotate the layer into screen orientation and scale and mirror
        textLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: 1.0, y: -1.0))
        return textLayer
    }

    func createRoundedRectLayerWithBounds(_ bounds: CGRect, identifier: String) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = identifier
        shapeLayer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1.0, 1.0, 0.2, 0.4])
        shapeLayer.cornerRadius = 7
        return shapeLayer
    }

        // MARK: - ARSessionDelegate
        
        // Pass camera frames received from ARKit to Vision (when not already processing one)
        /// - Tag: ConsumeARFrames
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
    //        // Do not enqueue other buffers for processing while another Vision task is still running.
    //        // The camera stream has only a finite amount of buffers available; holding too many buffers for analysis would starve the camera.
    //        guard pixbuff == nil, case .normal = frame.camera.trackingState else {
    //            return
    //        }
    //
    //        // Retain the image buffer for Vision processing.
    //        self.pixbuff = frame.capturedImage
    //        updateCoreML()
            
            // For debugging.
            //predict(image: UIImage(named: "dog416")!); return
            
            let pixelBuffer = frame.capturedImage
            
            // The semaphore will block the capture queue and drop frames when
            // 信号量将阻止捕获队列并在以下情况下丢弃帧
            // Core ML can't keep up with the camera.
            semaphore.wait()

            // For better throughput, we want to schedule multiple prediction requests
            // in parallel. These need to be separate instances, and inflightBuffer is
            // the index of the current request.
            // 为了获得更好的吞吐量
            // 我们希望并行安排多个预测请求
            // 这些需要是单独的实例
            // 并且inflightBuffer是当前请求的索引。
            let inflightIndex = inflightBuffer
            inflightBuffer += 1
            if inflightBuffer >= ViewController.maxInflightBuffers {
              inflightBuffer = 0
            }
            
            predictUsingVision(pixelBuffer: pixelBuffer, inflightIndex: inflightIndex)
            
        }
}

extension UIFont {
    // Based on: https://stackoverflow.com/questions/4713236/how-do-i-set-bold-and-italic-on-uilabel-of-iphone-ipad
    func withTraits(traits:UIFontDescriptor.SymbolicTraits...) -> UIFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptor.SymbolicTraits(traits))
        return UIFont(descriptor: descriptor!, size: 0)
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromCATextLayerAlignmentMode(_ input: CATextLayerAlignmentMode) -> String {
    return input.rawValue
}
