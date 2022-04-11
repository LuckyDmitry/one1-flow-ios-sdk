// Copyright 2021 1Flow, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import StoreKit

enum RatingStyle {
    case OneToTen
    case Stars
    case Emoji
    case MCQ
    case FollowUp
    case ReviewPrompt
    case ThankYou
}

typealias RatingViewCompletion = ((_ surveyResult: [SurveySubmitRequest.Answer]) -> Void)
typealias RecordOnlyEmptyTextCompletion = (() -> Void)

class OFRatingViewController: UIViewController {
    
    @IBOutlet weak var ratingView: OFDraggableView!
    @IBOutlet weak var containerView: OFRoundedConrnerView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var imgDraggView: UIImageView!
    @IBOutlet weak var dragViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewPrimaryTitle1: UIView!
    @IBOutlet weak var viewSecondaryTitle: UIView!
    @IBOutlet weak var lblPrimaryTitle1: UILabel!
    @IBOutlet weak var lblSecondaryTitle: UILabel!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var poweredByButton: UIButton!
    @IBOutlet weak var bottomView: UIView!

    private var isKeyboardVisible = false

    var originalPosition: CGPoint?
    var currentPositionTouched: CGPoint?

    var allScreens: [SurveyListResponse.Survey.Screen]?
    var surveyResult = [SurveySubmitRequest.Answer]()
    
    var completionBlock: RatingViewCompletion?
    var currentScreenIndex = -1
    var recordEmptyTextCompletionBlock: RecordOnlyEmptyTextCompletion?
    
    private var isClosingAnimationRunning: Bool = false
    private var shouldShowRating: Bool = false
    private var shouldOpenUrl: Bool = false

    lazy var waterMarkURL = "https://1flow.app/?utm_source=1flow-ios-sdk&utm_medium=watermark&utm_campaign=real-time+feedback+powered+by+1flow"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .light
        } else {
            // Fallback on earlier versions
        }
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWasShown(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        let width = self.view.bounds.width * 0.119
        self.dragViewWidthConstraint.constant = width
        self.imgDraggView.layer.cornerRadius = 2.5
        
        self.containerView.alpha = 0.0
        self.ratingView.alpha = 0.0
        
        self.ratingView.layer.shadowColor = UIColor.black.cgColor
        self.ratingView.layer.shadowOpacity = 0.25
        self.ratingView.layer.shadowOffset = CGSize.zero
        self.ratingView.layer.shadowRadius = 8.0
        
        self.setPoweredByButtonText(fullText: " Powered by 1Flow", mainText: " Powered by ", creditsText: "1Flow")
    }
    
    func setPoweredByButtonText(fullText: String, mainText: String, creditsText: String) {
        let fontBig = UIFont.systemFont(ofSize: 12, weight:.regular)
        let fontSmall = UIFont.systemFont(ofSize: 12, weight:.bold)
        let attributedString = NSMutableAttributedString(string: fullText, attributes: nil)
        
        let bigRange = (attributedString.string as NSString).range(of: mainText)
        let creditsRange = (attributedString.string as NSString).range(of: creditsText)
        attributedString.setAttributes([NSAttributedString.Key.font: fontBig as Any, NSAttributedString.Key.foregroundColor: UIColor.colorFromHex("50555C")], range: bigRange)
        attributedString.setAttributes([NSAttributedString.Key.font: fontSmall as Any, NSAttributedString.Key.foregroundColor: UIColor.colorFromHex("50555C")], range: creditsRange)
        
        self.poweredByButton.setAttributedTitle(attributedString, for: .normal)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.progressBar.tintColor = kPrimaryColor
        UIView.animate(withDuration: 0.2) {
            self.view.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        } completion: { _ in
            
        }
        if self.currentScreenIndex == -1 {
            self.presentNextScreen(nil)
        }
        let radius: CGFloat = 5.0
        self.bottomView.roundCorners(corners: [.bottomLeft, .bottomRight], radius: radius)
    }
    
    @IBAction func onClickWatermark(_ sender: Any) {
        guard let url = URL(string: waterMarkURL) else {
            return
        }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [ : ], completionHandler: nil)
        }
    }
    
    override var shouldAutorotate: Bool {
        return false
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return UIInterfaceOrientation.portrait
    }

    @objc func keyboardWasShown(notification: NSNotification) {
        let info = notification.userInfo!
        let keyboardFrame: CGRect = (info[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        self.isKeyboardVisible = true
        self.bottomConstraint.constant = keyboardFrame.size.height //+ 20
        self.ratingView.setNeedsUpdateConstraints()
        UIView.animate(withDuration: 0.4, animations: { () -> Void in
            self.view.layoutIfNeeded()
        })
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        self.isKeyboardVisible = false
        
        self.bottomConstraint.constant = 0
        self.ratingView.setNeedsUpdateConstraints()
        UIView.animate(withDuration: 0.4, animations: { () -> Void in
            self.view.layoutIfNeeded()
        })
    }
    //MARK: -
    
    fileprivate func presentNextScreen(_ previousAnswer : String?) {
        if let newIndex = self.getNextQuestionIndex(previousAnswer) {
            currentScreenIndex = newIndex
            if self.allScreens!.count > self.currentScreenIndex, let screen = self.allScreens?[self.currentScreenIndex] {
                self.setupUIAccordingToConfiguration(screen)
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                    self.progressBar.setProgress(Float(CGFloat(self.currentScreenIndex + 1 )/CGFloat(self.allScreens!.count - 1)), animated: true)
                }
            } else {
                //finish the survey
                guard let completion = self.completionBlock else { return }
                self.runCloseAnimation {
                    completion(self.surveyResult)
                }
            }
        }
        else {
            OneFlowLog.writeLog("Data Logic : No need to show next question as rating or open url action is performed")
        }
    }

    fileprivate func getNextQuestionIndex(_ previousAnswer : String?) -> Int? {
        var nextSurveyIndex : Int!
        if currentScreenIndex == -1 {
            nextSurveyIndex = currentScreenIndex + 1
            return nextSurveyIndex
        }
        OneFlowDataLogic().getNextAction(currentIndex: currentScreenIndex, allSurveys: self.allScreens!, previousAnswer : previousAnswer,  completion: { (action, nextIndex, urlToOpen) -> Void in
            if let actionToPerform : String  = action {
                if actionToPerform == "open-url" {
                    if let actionUrl : String = urlToOpen {
                        self.performOpenUrlAction(actionUrl)
                        return
                    }
                }
                else if actionToPerform == "rating" {
                    self.performRatingAction()
                    return
                }
                else if actionToPerform == "skipTo" {
                    if let nextQuestionIndex : Int = nextIndex {
                        nextSurveyIndex = nextQuestionIndex
                    }
                }
            }
            else {
                OneFlowLog.writeLog("Data Logic : No Action detected for this question")
                nextSurveyIndex = currentScreenIndex + 1

            }
        })
        return nextSurveyIndex
    }

    private func performRatingAction() {
        currentScreenIndex = -2
        guard let completion = self.completionBlock else { return }
        self.runCloseAnimation {
            self.openRatemePopup()
            completion(self.surveyResult)
        }
    }

    private func openRatemePopup() {
        if #available(iOS 14.0, *) {
            if let currentWindowScene = UIApplication.shared.connectedScenes
                .filter({$0.activationState == .foregroundActive})
                .compactMap({$0 as? UIWindowScene})
                .first {
                SKStoreReviewController.requestReview(in: currentWindowScene)
            }
            else {
                OneFlowLog.writeLog("Could not fetch currentWindowScene while showing rating")
            }
        } else {
            SKStoreReviewController.requestReview()
        }
    }

    private func openAppStoreRateMeUrl(){
        
        OFAPIController().getAppStoreDetails { [weak self] isSuccess, error, data in
            guard self != nil else {
                return
            }
            if isSuccess == true, let data = data {
                do{
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any]
                    if let results : NSArray =  json!["results"] as? NSArray {
                        if results.count > 0 {
                            let result : NSDictionary = results.firstObject as! NSDictionary
                            if let trackId = result["trackId"]{
                                let ratingUrl = "https://itunes.apple.com/app/id\(trackId)?action=write-review" // (Option 2) Open App Review Page
                                OneFlowLog.writeLog("Data Logic : App store rating Url : \(ratingUrl)")

                                guard let url = URL(string: ratingUrl) else {
                                    return
                                }
                                DispatchQueue.main.async {
                                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                                }
                            }
                        }
                        else {
                            OneFlowLog.writeLog("Data Logic : App Store track ID not found")
                        }
                    }
                }catch{
                    OneFlowLog.writeLog("Data Logic : App Store Url not found")
                }
                 
                
            } else {
                OneFlowLog.writeLog(error?.localizedDescription ?? "NA")
            }
        }
    }
    
    private func performOpenUrlAction(_ urlString : String) {
        currentScreenIndex = -2
        guard let completion = self.completionBlock else { return }
        self.runCloseAnimation {
            guard let url = URL(string: urlString) else {
                OneFlowLog.writeLog("Data Logic : Invalid Url received from server")
                completion(self.surveyResult)
                return
            }
            DispatchQueue.main.async {
                if UIApplication.shared.canOpenURL(url) {
                    OneFlowLog.writeLog("Data Logic : Opening Url  : \(url.absoluteURL)")
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
                else {
                    OneFlowLog.writeLog("Data Logic : Can not open url : \(url.absoluteURL)")
                }
                
            }
            completion(self.surveyResult)
        }
    }
    
    private func setupUIAccordingToConfiguration(_ currentScreen: SurveyListResponse.Survey.Screen) {

        self.stackView.alpha = 0.0
        if let value = currentScreen.title {
            self.viewPrimaryTitle1.isHidden = false
            self.lblPrimaryTitle1.text = value
        } else {
            self.viewPrimaryTitle1.isHidden = true
        }

        if let value = currentScreen.message, value.count > 0 {
            self.viewSecondaryTitle.isHidden = false
            self.lblSecondaryTitle.text = value
        } else {
            self.viewSecondaryTitle.isHidden = true
        }

        let indexToAddOn = 2
        if self.stackView.arrangedSubviews.count > indexToAddOn {
            let subView = self.stackView.arrangedSubviews[indexToAddOn]
            subView.removeFromSuperview()
        }
        
        if currentScreen.input?.input_type == "text" {
            let view = OFFollowupView.loadFromNib()
            view.delegate = self
            view.placeHolderText = currentScreen.input!.placeholder_text ?? "Write here..."
            view.maxCharsAllowed = currentScreen.input!.max_chars ?? 1000
            view.minCharsAllowed = currentScreen.input!.min_chars ?? 5
            if let buttonArray = currentScreen.buttons {
                if buttonArray.count > 0 {
                    if let buttonTitle = buttonArray.first?.title {
                        view.submitButtonTitle = buttonTitle
                    }
                }
            }
            view.isHidden = true
            self.stackView.insertArrangedSubview(view, at: indexToAddOn)
            
        } else if currentScreen.input?.input_type == "rating" ||  currentScreen.input?.input_type == "rating-5-star" {
            let view = OFStarsView.loadFromNib()
            view.delegate = self
            view.isHidden = true
            self.stackView.insertArrangedSubview(view, at: indexToAddOn)
        } else if currentScreen.input?.input_type == "rating-emojis" {
            let view = OFOneToTenView.loadFromNib()
            view.isForEmoji = true
            view.emojiArray = ["☹️", "🙁", "😐", "🙂", "😊"]
            view.delegate = self
            view.isHidden = true
            self.stackView.insertArrangedSubview(view, at: indexToAddOn)
        } else if currentScreen.input?.input_type == "rating-numerical" {
            let view = OFOneToTenView.loadFromNib()
            view.delegate = self
            view.minValue = 1
            view.maxValue = 5
            view.ratingMinText = currentScreen.input?.rating_min_text
            view.ratingMaxText = currentScreen.input?.rating_max_text
            view.isHidden = true
            self.stackView.insertArrangedSubview(view, at: indexToAddOn)
        } else if currentScreen.input?.input_type == "nps" {
            let view = OFOneToTenView.loadFromNib()
            view.delegate = self
            view.minValue = currentScreen.input?.min_val ?? 0
            view.maxValue = currentScreen.input?.max_val ?? 10
            view.ratingMinText = currentScreen.input?.rating_min_text
            view.ratingMaxText = currentScreen.input?.rating_max_text
            view.isHidden = true
            self.stackView.insertArrangedSubview(view, at: indexToAddOn)
        } else if currentScreen.input?.input_type == "mcq" {
            let view = OFMCQView.loadFromNib()
            view.delegate = self
            view.currentType = .radioButton
            if let titleArray = currentScreen.input!.choices?.map({ return $0 }) {
                view.setupViewWithOptions(titleArray, type: .radioButton, parentViewWidth: self.stackView.bounds.width, currentScreen.input?.other_option_id)
            }
            view.isHidden = true
            self.stackView.insertArrangedSubview(view, at: indexToAddOn)
        } else if currentScreen.input?.input_type == "checkbox" {
            let view = OFMCQView.loadFromNib()
            view.delegate = self
            view.currentType = .checkBox
            if let titleArray = currentScreen.input!.choices?.map({ return $0 }) {
                view.setupViewWithOptions(titleArray, type: .checkBox, parentViewWidth: self.stackView.bounds.width, currentScreen.input?.other_option_id)
            }
            view.isHidden = true
            self.stackView.insertArrangedSubview(view, at: indexToAddOn)
        } else if currentScreen.input?.input_type == "thank_you" {
            self.progressBar.isHidden = true
            self.viewPrimaryTitle1.isHidden = true
            self.viewSecondaryTitle.isHidden = true
            let view = OFThankYouView.loadFromNib()
            view.delegate = self
            view.isHidden = true
            self.stackView.insertArrangedSubview(view, at: indexToAddOn)
        }

        for subview in self.stackView.arrangedSubviews {
            subview.alpha = 0.0
        }
        
        UIView.animate(withDuration: 0.3) {
            if self.stackView.arrangedSubviews.count > 2 {
                self.stackView.arrangedSubviews[2].isHidden = false
            }
            
        } completion: { _ in
            self.stackView.alpha = 1.0
            
            if self.currentScreenIndex == 0 {
                let originalPosition = self.ratingView.frame.origin.y
                self.ratingView.frame.origin.y = self.view.frame.size.height
                self.ratingView.alpha = 1.0
                self.containerView.alpha = 1.0
                UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: UIView.AnimationOptions.curveEaseInOut) {
                    self.ratingView.frame.origin.y = originalPosition
                } completion: { _ in
                    var totalDelay = 0.0
                    for subView in self.stackView.arrangedSubviews {
                        UIView.animate(withDuration: 0.5, delay: totalDelay, options: UIView.AnimationOptions.allowUserInteraction) {
                            subView.alpha = 1.0
                        } completion: { _ in

                        }
                        totalDelay += 0.2
                    }
                    
                }

            } else {
                var totalDelay = 0.0
                for subView in self.stackView.arrangedSubviews {
                    UIView.animate(withDuration: 0.5, delay: totalDelay, options: UIView.AnimationOptions.allowUserInteraction) {
                        subView.alpha = 1.0
                    } completion: { _ in

                    }
                    totalDelay += 0.2
                }
            }
        }
        
        
    }
    
    
    func runCloseAnimation(_ completion: @escaping ()-> Void) {
        self.isClosingAnimationRunning = true
        UIView.animate(withDuration: 0.5) {
            self.ratingView.frame.origin.y = self.ratingView.frame.origin.y + self.ratingView.frame.size.height
        }
        
        UIView.animate(withDuration: 0.3, delay: 0.5, options: UIView.AnimationOptions.curveEaseIn) {
            self.view.backgroundColor = UIColor.clear
        } completion: { _ in
            completion()
        }
    }
    
    @objc func tapGestureAction(_ panGesture: UITapGestureRecognizer) {
        OneFlowLog.writeLog("tapGestureAction called")
        onBlankSpaceTapped(panGesture)
    }
    
    @objc func panGestureAction(_ panGesture: UIPanGestureRecognizer) {
        let translation = panGesture.translation(in: ratingView)
        if panGesture.state == .began {
            originalPosition = ratingView.center
            currentPositionTouched = panGesture.location(in: ratingView)
            
        } else if panGesture.state == .changed {
            if translation.y > 0 {
                ratingView.frame.origin = CGPoint(
                    x: ratingView.frame.origin.x,
                    y: (originalPosition?.y ?? 0) - (ratingView.frame.size.height / 2) + translation.y
                )
            }
            
        } else if panGesture.state == .ended {
            let velocity = panGesture.velocity(in: ratingView)
            
            if velocity.y >= 1500 {
                UIView.animate(withDuration: 0.2
                               , animations: {
                                self.ratingView.frame.origin = CGPoint(
                                    x: self.ratingView.frame.origin.x,
                                    y: self.view.frame.size.height
                                )
                               }, completion: { (isCompleted) in
                                if isCompleted {
                                    guard let completion = self.completionBlock else { return }
                                    completion(self.surveyResult)
                                }
                               })
            } else {
                UIView.animate(withDuration: 0.2, animations: {
                    self.ratingView.center = self.originalPosition!
                })
            }
        }
    }

    @IBAction func onBlankSpaceTapped(_ sender: Any) {
        if self.isKeyboardVisible == true {
            self.view.endEditing(true)
            return
        }
        guard let completion = self.completionBlock else { return }
        self.runCloseAnimation {
            completion(self.surveyResult)
        }
    }
    

    @IBAction func onCloseTapped(_ sender: UIButton) {

        if self.isKeyboardVisible == true {
            self.view.endEditing(true)
        }
        guard let completion = self.completionBlock else { return }
        self.runCloseAnimation {
            completion(self.surveyResult)
        }
    }
    
    
}

extension OFRatingViewController : UIGestureRecognizerDelegate {
    
}

extension OFRatingViewController: OFRatingViewProtocol {
    
    func oneToTenViewChangeSelection(_ selectedIndex: Int?) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
            if let index = selectedIndex, let screen = self.allScreens?[self.currentScreenIndex] {
                let answer = SurveySubmitRequest.Answer(screen_id: screen._id, answer_value: "\(index)", answer_index: nil)
                self.surveyResult.append(answer)
                self.presentNextScreen(answer.answer_value)
            }
        }
    }
    
    func mcqViewChangeSelection(_ selectedOptionID: String,_ otherTextAnswer : String?) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
            if  let screen = self.allScreens?[self.currentScreenIndex] {
                let answer = SurveySubmitRequest.Answer(screen_id: screen._id, answer_value: otherTextAnswer, answer_index: selectedOptionID)
                self.surveyResult.append(answer)
                self.presentNextScreen(answer.answer_index)
            }
        }
    }
    
    func checkBoxViewDidFinishPicking(_ selectedOptions: [String], _ otherTextAnswer: String?) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
            if let screen = self.allScreens?[self.currentScreenIndex] {       
                let finalString = selectedOptions.joined(separator: ",")
                let answer = SurveySubmitRequest.Answer(screen_id: screen._id, answer_value: otherTextAnswer, answer_index: finalString)
                self.surveyResult.append(answer)
                self.presentNextScreen(answer.answer_index)
            }
        }
    }
    
    func followupViewEnterTextWith(_ text: String?) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
            
            if let inputString = text, let screen = self.allScreens?[self.currentScreenIndex] {
                let finalString = inputString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if finalString.count > 0 {
                    let answer = SurveySubmitRequest.Answer(screen_id: screen._id, answer_value: inputString, answer_index: nil)
                    self.surveyResult.append(answer)
                } else {
                    if let screens = self.allScreens, screens.count == 1 {
                        if let completionEmptyText = self.recordEmptyTextCompletionBlock {
                            completionEmptyText()
                        }
                    } else if let screens = self.allScreens, screens.count <= 2, let lastScreen = screens.last, lastScreen.input?.input_type == "thank_you" {
                        if let completionEmptyText = self.recordEmptyTextCompletionBlock {
                            completionEmptyText()
                        }
                    }
                }
                self.view.endEditing(true)
                self.presentNextScreen(inputString)
            }
        }
    }
    
    func starsViewChangeSelection(_ selectedIndex: Int?) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
            if let index = selectedIndex, let screen = self.allScreens?[self.currentScreenIndex] {
                let answer = SurveySubmitRequest.Answer(screen_id: screen._id, answer_value: "\(index)", answer_index: nil)
                self.surveyResult.append(answer)
                self.presentNextScreen(answer.answer_value)
            }
        }
    }
    
    func onThankyouAnimationComplete() {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
            if self.isClosingAnimationRunning == true {
                return
            }
            guard let completion = self.completionBlock else { return }
            self.runCloseAnimation {
                completion(self.surveyResult)
            }
        }
    }
}
