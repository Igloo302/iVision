/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Contains the view controller for the Breakfast Finder.
 */

import UIKit
import AVFoundation
import Vision
import Speech
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, SFSpeechRecognizerDelegate {
    
    // MARK: Properties
    let runARSession = true
    var showLayer = true
    var showNode = true
    var runCoreML = true
    
    
    // 界面UI
    
    @IBOutlet var stopButton: UIButton!
    @IBOutlet var helpButton: UIButton!
    @IBOutlet var settingButton: UIButton!
    @IBOutlet var addButton: UIButton!
    @IBOutlet var recordButton: UIButton!
    @IBOutlet var textView: UILabel!
    @IBOutlet weak var debugTextView: UILabel!
    @IBOutlet weak var sceneView: ARSCNView!
    
    // 语音转录变量
    let language = "zh-TW"
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    var userCommand = ""
    
    // 声音播放
//    let recordStartSound = URL(fileURLWithPath: Bundle.main.path(forResource: "btn_recordStart", ofType: "wav")!)
//    let recordStopSound = URL(fileURLWithPath: Bundle.main.path(forResource: "btn_recordStop", ofType: "wav")!)
//    var audioPlayer = AVAudioPlayer()
    
    var audioSource: SCNAudioSource!
    var cube = SCNNode(geometry: SCNBox(width: 0.1, height: 0.1, length: 0.1, chamferRadius: 0))
    
    
    
    // Tweak these values to get more or fewer predictions.
    let confidenceThreshold: Float = 0.8
    let iouThreshold: Float = 0.5
    
    // 识别的物体
    struct Prediction {
        var classIndex: Int
        var score: Float
        var rect: CGRect
        var worldCoord: [SCNVector3]
    }
    var predictions = [Prediction]()
    
    var nodes = [SCNNode]()
    
    struct object{
        let chinese:[String]
        let english:String
    }
    
    // 识别到的物体的字典
    let labelsList = [object(chinese: ["显示器","液晶屏"], english: "tvmonitor"),
                     object(chinese: ["椅子","凳子"], english: "chair"),
                     object(chinese: ["盆栽","盆景"], english: "pottedplant"),
                     object(chinese: ["瓶子"], english: "bottle"),
                     object(chinese: ["水杯","瓶子","杯子"], english: "cup"),
                     object(chinese: ["香蕉"], english: "banana"),
                     object(chinese: ["苹果"], english: "apple"),
                     object(chinese: ["书"], english: "book"),
                     object(chinese: ["包"], english: "bag"),
                     object(chinese: ["鼠标"], english: "mouse"),
                     object(chinese: ["键盘"], english: "keyboard"),
                     object(chinese: ["手机"], english: "cell phone")
    ]
    
    //计时器
    var startTimes: [CFTimeInterval] = []
    
    // 显示识别结果的Bounding的图层
    var detectionOverlay: CALayer! = nil
    var rootLayer: CALayer! = nil
    
    // 显示区域尺寸
    var bufferSize: CGSize = .zero
    
    // COREML
    var visionRequests = [VNRequest]()
    
    let bubbleDepth : Float = 0.01 // the 'depth' of 3D text 文字的厚度
    
    // MARK: - View Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupRecognizers()
        
        // 背景图设置
        stopButton.titleLabel?.layer.opacity = 0
        stopButton.backgroundColor = UIColor(red: 0, green: 0.8, blue: 0, alpha: 0.5)
        stopButton.isHidden = true
        recordButton.titleLabel?.layer.opacity = 0
        recordButton.imageView?.contentMode = .scaleAspectFit
        helpButton.imageView?.contentMode = .scaleAspectFit
        settingButton.imageView?.contentMode = .scaleAspectFit
        addButton.imageView?.contentMode = .scaleAspectFit
        
        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false
        //recordButton.setImage(UIImage(named: "find"), for: .disabled)
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        // Show statistics such as fps and timing information
        // sceneView.showsStatistics = true
        
        sceneView.preferredFramesPerSecond = 30
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // Enable Default Lighting - makes the 3D text a bit poppier.
        sceneView.autoenablesDefaultLighting = true
        
        // sceneView.debugOptions = [.showFeaturePoints]
        
        bufferSize = CGSize(width: sceneView.bounds.height, height: sceneView.bounds.width)
        print("😎把BufferSize设置成", bufferSize)
        
        //配置Layer初始化
        rootLayer = sceneView.layer
        setupLayers()
        updateLayerGeometry()
        
        // 设置YOLO识别器
        // Vision classification request and model
        guard let modelURL = Bundle.main.url(forResource: "YOLOv3Tiny", withExtension: "mlmodelc") else {fatalError("没有找到YOLOv3模型，凉凉")
        }
        do {
            // 载入模型
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            print("😎SceneKit所需模型载入成功")
            // 使用该模型创建一个VNCoreMLRequest，识别到之后执行completionHandler里面的部分
            let ARobjectRecognition = VNCoreMLRequest(model: visionModel, completionHandler: objectRecognitionCompleteHandler)
            
            // Crop input images to square area at center, matching the way the ML model was trained.
            
            // NOTE: If you choose another crop/scale option, then you must also
            // change how the BoundingBox objects get scaled when they are drawn.
            // Currently they assume the full input image is used.
            ARobjectRecognition.imageCropAndScaleOption = .scaleFill
            
            // Use CPU for Vision processing to ensure that there are adequate GPU resources for rendering.
            // ARobjectRecognition.usesCPUOnly = true
            
            visionRequests = [ARobjectRecognition]
        } catch let error as NSError {
            print("Model loading went wrong: \(error)")
        }
        
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Prevent the screen from being dimmed to avoid interuppting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Enable plane detection
        // configuration.planeDetection = [.horizontal, .vertical]
        
        // Run the view's session
        if runARSession {
            sceneView.session.run(configuration)
            print("😎AR Configuration载入成功")
        }
        
        
        
        // 语音转录
        // Configure the SFSpeechRecognizer object already
        // stored in a local member variable.
        speechRecognizer.delegate = self
        
        
        // Asynchronously make the authorization request.
        SFSpeechRecognizer.requestAuthorization { authStatus in

            // Divert to the app's main thread so that the UI
            // can be updated.
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recordButton.isEnabled = true
                    
                case .denied:
                    self.recordButton.isEnabled = false
                    //self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)
                    //self.recordButton.setImage(UIImage(named: "find"), for: .disabled)
                    
                case .restricted:
                    self.recordButton.isEnabled = false
                    //self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)
                    //self.recordButton.setImage(UIImage(named: "find"), for: .disabled)
                    
                case .notDetermined:
                    self.recordButton.isEnabled = false
                    //self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                    //self.recordButton.setImage(UIImage(named: "find"), for: .disabled)
                    
                default:
                    self.recordButton.isEnabled = false
                    //self.recordButton.setImage(UIImage(named: "find"), for: .disabled)
                    
                }
            }
        }
        
        // 开启引导
        Speak("请缓慢移动手机，扫描周围环境")
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: SFSpeechRecognizer
    
    private func startRecording() throws {
        
        // Cancel the previous task if it's running.
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        // Configure the audio session for the app.
        try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
        try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode

        // Create and configure the speech recognition request.
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
        recognitionRequest.shouldReportPartialResults = true
        
        // Keep speech recognition data on device
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }
        
        //clean userCommand
        userCommand = ""
        
        // Create a recognition task for the speech recognition session.
        // Keep a reference to the task so that it can be canceled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                // Update the text view with the results.
                self.textView.text = result.bestTranscription.formattedString
                isFinal = result.isFinal
                // print("Text \(result.bestTranscription.formattedString)")
                self.userCommand = result.bestTranscription.formattedString
            }
            
            if error != nil || isFinal {
                // Stop recognizing speech if there is a problem. 这个地方的问题是应该不存在result.Final的情况
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                self.recordButton.isEnabled = true
                //self.recordButton.setTitle("Start Recording", for: [])
                //self.recordButton.setImage(UIImage(named: "find"), for: .normal)
            }
        }

        // Configure the microphone input.
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // Let the user know to start talking.
        textView.text = "你要找什么？"
    }
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
            //recordButton.setTitle("Start Recording", for: [])
            //recordButton.setImage(UIImage(named: "find"), for: .normal)
        } else {
            recordButton.isEnabled = false
            //recordButton.setTitle("Recognition Not Available", for: .disabled)
            //recordButton.setImage(UIImage(named: "find"), for: .disabled)
        }
    }
    
    // MARK: Interface Builder actions
    
    @IBAction func recordButtonTapped() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            //recordButton.setTitle("Stopping", for: .disabled)
            //recordButton.setImage(UIImage(named: "find"), for: .disabled)
            
            
            // 把音频模式改回来
            do {
                try AVAudioSession.sharedInstance().setCategory(.soloAmbient, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            } catch {}
            
            recordButton.backgroundColor = UIColor(red: 0.8, green: 0, blue: 0, alpha: 0)
            
            
            // 调用关键词匹配
            let objectIndex = objectIsWanted(from: userCommand)
            
            if objectIndex != -1 {
                search(objectIndex)
            }
        } else {
            do {
                Speak("你想找啥?")
                
                recordButton.backgroundColor = UIColor(red: 0.8, green: 0, blue: 0, alpha: 0.5)

                try startRecording()
                //recordButton.setTitle("Stop Recording", for: [])
                //recordButton.setImage(UIImage(named: "finding"), for: .normal)
                
            } catch {
                //recordButton.setTitle("Recording Not Available", for: [])
                //recordButton.setImage(UIImage(named: "find"), for: .disabled)
            }
        }
    }
    
    
    @IBAction func stopButtonTapped() {
        
        stopButton.isHidden = true
        recordButton.isHidden = false
        
        // 移除声音
        for node in nodes {
            node.removeAllAudioPlayers()
        }
    }
        
        
    // 让Siri说说话
    func Speak(_ stringToSpeak: String){
        let utterance = AVSpeechUtterance(string: stringToSpeak)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
        // print(stringToSpeak)
        
    }
    
    @IBAction func addButtonTapped(){
//        do {
//            audioPlayer = try AVAudioPlayer(contentsOf: recordStopSound)
//            audioPlayer.play()
//        } catch {
//            // couldn't load file :(
//        }
        Speak("更多功能，敬请期待")
    }
    
    // add form exsitingPlaneUsingExtent
    @objc func didTap(recognizer:UITapGestureRecognizer){
        let tapPoint = recognizer.location(in: sceneView)
        print(tapPoint)
        
    }
    func setupRecognizers() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.didTap(recognizer:) ))
        tapGestureRecognizer.numberOfTapsRequired = 1
        sceneView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    // MARK: - ARSessionDelegate
    
    // Pass camera frames received from ARKit to Vision (when not already processing one)
    /// - Tag: ConsumeARFrames
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        // Do not enqueue other buffers for processing while another Vision task is still running.
        // The camera stream has only a finite amount of buffers available; holding too many buffers for analysis would starve the camera.
        guard pixbuff == nil, case .normal = frame.camera.trackingState else {
            return
        }
        
        // camere的尺寸
        //print(frame.camera.imageResolution)
        
        if runCoreML {
            updateCoreML()
        }
       
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        debugTextView.text = "Session failed: \(error.localizedDescription). Resetting the AR session."
        // resetTracking()
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        debugTextView.text = "Session was interrupted"
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        debugTextView.text = "Session interruption ended"
        // If object has not been placed yet, reset tracking
        //        if previewNode != nil {
        //            resetTracking()
        //        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - CoreML Vision Handling
    
    private let visionQueue = DispatchQueue(label: "com.example.apple-samplecode.ARKitVision.serialVisionQueue")
    // The pixel buffer being held for analysis; used to serialize Vision requests.
    private var pixbuff: CVPixelBuffer?
    
    // ✌️重要！把画面弄到core ML模型进行识别的部分！
    func updateCoreML() {
        // Get Camera Image as RGB SCENEVIEW的图片就用当前帧的画面弄出来就行
        pixbuff  = sceneView.session.currentFrame?.capturedImage
        
        
        // if pixbuff == nil { return }
        
        // 计时器
        startTimes.append(CACurrentMediaTime())
        
        // Prepare CoreML/Vision Request，VNImageRequestHandler是处理与单个图像有关的一个或多个图像分析请求的对象
        // Vision will automatically resize the input image.
        // 需要把画面时针旋转90度，但是我也不知道为什么🤷‍♂️
        let exifOrientation = exifOrientationFromDeviceOrientation()
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixbuff!, orientation: exifOrientation, options: [:])
        
        // Run Image Request
        visionQueue.async {
            do {
                // Release the pixel buffer when done, allowing the next buffer to be processed.
                // defer 所声明的 block 会在当前代码执行退出后被调用
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
        // print(String(format: "Elapsed %.5f seconds", elapsed))
        
        showOnMainThread(observations, elapsed)
    }
    
    
    // MARK: - Result
    
    func showOnMainThread(_ observations: [Any],_ elapsed: CFTimeInterval){
        //删除之前的sublayers
        detectionOverlay.sublayers = nil
        
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
            // 取置信度高的
            if topLabelObservation.confidence > confidenceThreshold {
                
                // 判断一下这个物体是不是在列表中的
                let Index = getClassIndex(topLabelObservation.identifier)
                if Index == -1{
                    continue
                }
                
                // 沙雕代码 2019.10.24
                // 根据不同的旋转情况改boundingbox位置
                let boundbox = CGRect(x: 1-objectObservation.boundingBox.maxY, y: objectObservation.boundingBox.minX, width: objectObservation.boundingBox.height, height: objectObservation.boundingBox.width)
                
                //let boundbox = objectObservation.boundingBox
                //bufferSize = CGSize(width: sceneView.bounds.size.height, height: sceneView.bounds.size.width)
                
                let objectBounds = VNImageRectForNormalizedRect(boundbox, Int(bufferSize.width), Int(bufferSize.height))
                
                updatePredictions(objectBounds, Index: Index, confidence: topLabelObservation.confidence)
                
                DispatchQueue.main.async {
                    self.updateUI(topLabelObservation)
                    
                    if self.showLayer {
                        self.updateLayer(topLabelObservation, objectBounds)
                    }
                }
            }
        }
    }
    
    
    // MARK: - Point Control
    
    func updatePredictions(_ rect: CGRect, Index: Int, confidence: VNConfidence){
        // 判断这个点和手机当前位置不能太近
        guard getWorldCoord(rect).x != 0 else{
            return
        }
        if let i = predictions.firstIndex(where: {$0.classIndex == Index}){
            // 如果已经存在，就更新这个prediction
                predictions[i].score = 100 * confidence
                predictions[i].rect = rect
                predictions[i].worldCoord.append(getWorldCoord(rect))
                // 移动node位置
                if let j = nodes.firstIndex(where: {getClassIndex($0.name!) == Index}){
                    nodes[j].position = predictions[i].worldCoord.last!
                }
        }else{
            // 如果没有这个prediction，就创建新prediction
            let prediction = Prediction(classIndex: Index,
                                        score: confidence * 100,
                                        rect: rect,
                                        worldCoord: [getWorldCoord(rect)])
            //print(prediction)
            predictions.append(prediction)
            //创建新node
            // print("Add New Node")
            let node = createNewBubbleParentNode(labelsList[Index].english)

            
            node.position = prediction.worldCoord.last!
            node.name = labelsList[Index].english
            nodes.append(node)
            if showNode{
                sceneView.scene.rootNode.addChildNode(node)
            }
        }
    }
    
    func getClassIndex(_ identifier: String) -> Int{
        if let i = labelsList.firstIndex(where: {$0.english == identifier}){
            return i
        }else{
            return -1
        }
    }
    
    // Hittest获得世界坐标
    func getWorldCoord(_ rect: CGRect) -> SCNVector3{
        
        let screenPoint = CGPoint(x:rect.midY, y: rect.midX)
        let HitTestResults : [ARHitTestResult] = sceneView.hitTest(screenPoint, types: [.featurePoint])
        
        if let closestResult = HitTestResults.first {
            // Get Coordinates of HitTest
            let transform : matrix_float4x4 = closestResult.worldTransform
            let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            return worldCoord
        }else{return SCNVector3(0, 0, 0)}
    }
    
    // MARK: - Fake NLU
    func objectIsWanted(from userCommand: String) -> Int {
        for label in labelsList {
            for name in label.chinese {
                if userCommand.contains(name){
                    //print("想找的是", name,label.english, getClassIndex(label.english))
                    return getClassIndex(label.english)
                }
            }
        }
        // 没有解析到关键词
        Speak("对不起，我没听懂")
        return -1
    }
    
    // MARK: - Search Object
    
    func search(_ Index: Int){
        if let i = nodes.firstIndex(where: {$0.name == labelsList[Index].english}){
            // 存在这个node
            Speak(String(labelsList[Index].chinese.first! + "在这儿"))
            setUpAudio(labelsList[Index].english)
            nodes[i].removeAllAudioPlayers()
            nodes[i].addAudioPlayer(SCNAudioPlayer(source: audioSource))
            
            // 录音按钮隐藏，显示停止寻找按钮
            recordButton.isHidden = true
            stopButton.isHidden = false
            
        } else{
            // 不存在这个node
            waitFor(Index)
        }
    }
    
    func waitFor(_ Index: Int){
        Speak(String("没找到" + labelsList[Index].chinese.first!))
        // 增加wait
    }
    
    // MARK: - Audio
    
    /// Sets up the audio for playback.
    /// - Tag: SetUpAudio
    private func setUpAudio(_ name: String) {
        
        // Instantiate the audio source
        audioSource = SCNAudioSource(fileNamed: "fireplace.mp3")
        //audioSource = SCNAudioSource(fileNamed: "\(name).mp3")
        // As an environmental sound layer, audio should play indefinitely
        audioSource.loops = true
        // Decode the audio from disk ahead of time to prevent a delay in playback
        audioSource.load()
    }
    
    
    // MARK: - SCNNode Creator
    
    func createNewBubbleParentNode(_ text : String) -> SCNNode {
        // Warning: Creating 3D Text is susceptible to crashing. To reduce chances of crashing; reduce number of polygons, letters, smoothness, etc.
        let bubbleNodeParent = SCNNode()
        bubbleNodeParent.addChildNode(createBubbleNode(name: text))
        bubbleNodeParent.addChildNode(createSphereNode())
        bubbleNodeParent.constraints = [createBillboardConstraint()]
        
        return bubbleNodeParent
    }
    
    private func createBubbleNode(name: String) -> SCNNode {
        let bubble = createBubble(text: name)
        let (minBound, maxBound) = bubble.boundingBox
        let bubbleNode = SCNNode(geometry: bubble)
        // Centre Node - to Centre-Bottom point
        bubbleNode.pivot = SCNMatrix4MakeTranslation( (maxBound.x - minBound.x)/2, minBound.y, bubbleDepth/2)
        // Reduce default text size
        bubbleNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
        
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
    // MARK: - UI
    
    func updateUI(_ topLabelObservation: VNClassificationObservation){
        var debugText:String = ""
        debugText += "\(topLabelObservation.identifier)" + "\(topLabelObservation.confidence)"
        self.debugTextView.text = debugText
    }
    
    //显示Layer
    func updateLayer(_ topLabelObservation: VNClassificationObservation, _ objectBounds: CGRect){
        
        
        let shapeLayer = self.createRoundedRectLayerWithBounds(objectBounds, identifier: topLabelObservation.identifier)
        let textLayer = self.createTextSubLayerInBounds(objectBounds, identifier: topLabelObservation.identifier, confidence: topLabelObservation.confidence)
        // CATransaction.setDisableActions(true)
        shapeLayer.addSublayer(textLayer)
        self.detectionOverlay.addSublayer(shapeLayer)
        
    }
    
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
        var scale: CGFloat
        
        let xScale: CGFloat = rootLayer.bounds.size.width / bufferSize.height
        let yScale: CGFloat = rootLayer.bounds.size.height / bufferSize.width
        
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        //        CATransaction.begin()
        //        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // rotate the layer into screen orientation and scale and mirror
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        // center the layer
        detectionOverlay.position = CGPoint (x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        
        //        CATransaction.commit()
        
    }
    
    func createTextSubLayerInBounds(_ bounds: CGRect, identifier: String, confidence: VNConfidence) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.name = identifier
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
    
    func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        let curDeviceOrientation = UIDevice.current.orientation
        let exifOrientation: CGImagePropertyOrientation
        
        switch curDeviceOrientation {
        case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = .left
        case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, home button on the right
            exifOrientation = .up
        case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, home button on the left
            exifOrientation = .down
        case UIDeviceOrientation.portrait:            // Device oriented vertically, home button on the bottom
            exifOrientation = .right
        default:
            exifOrientation = .right
        }
        return exifOrientation
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

