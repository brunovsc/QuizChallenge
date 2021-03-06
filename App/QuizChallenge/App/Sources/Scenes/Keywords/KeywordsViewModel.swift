//
//  KeywordsViewModel.swift
//  QuizChallenge
//
//  Created by Eduardo Sanches Bocato on 21/09/19.
//  Copyright © 2019 Bocato. All rights reserved.
//

import Foundation

/// Defines a binding protocol between the viewModel and the ViewController
protocol KeywordsViewModelBinding: AnyObject {
    func viewTitleDidChange(_ title: String?)
    func textFieldPlaceholderDidChange(_ text: String?)
    func bottomRightTextDidChange(_ text: String?)
    func bottomLeftTextDidChange(_ text: String?)
    func bottomButtonTitleDidChange(_ title: String?)
    func textFieldShouldReset()
    func showTimerFinishedModalWithData(_ modalData: SimpleModalViewData)
    func showWinnerModalWithData(_ modalData: SimpleModalViewData)
    func showErrorModalWithData(_ modalData: SimpleModalViewData)
}

/// Defines the display logic for KeywordsViewController
protocol KeywordsViewModelDisplayLogic {
    
    /// Returns the number of answers to be shown on the screen
    var numberOfAnswers: Int { get }
    
    /// Get's the answer item for some index
    ///
    /// - Parameter index: some index
    /// - Returns: nil, if the index does not exist, `QuizViewData.Item` otherwise
    func answerItem(at index: Int) -> QuizViewData.Item?
    
    /// Defines operations to be done on viewDidLoad, normally initializations and setups
    func onViewDidLoad()
}

/// Defines the business logic for KeywordsViewController
protocol KeywordsViewModelBusinessLogic {
    
    /// Loads the quiz data from the necessary dataSources
    func loadQuizData()
    
    /// Toggles the timer on and off
    func toggleTimer()
    
    /// Resets the quiz and viewData related to it
    func resetQuiz()
    
    /// Verifies if the user has inputed a valid answer
    ///
    /// - Parameter input: the user input, from a textField
    func verifyTextFieldInput(_ input: String?)
}

final class KeywordsViewModel: KeywordsViewModelDisplayLogic {
    
    // MARK: - Dependencies
    
    private let timerPeriod: Int
    private let countDownTimer: CountDownTimerProvider
    private let fetchQuizUseCase: FetchQuizUseCaseProvider
    private let countDownFormatter: CountDownFormatting
    private var countRightAnswersUseCase: CountRightAnswersUseCaseProvider
    
    // MARK: - Binding
    
    weak var viewStateRenderer: ViewStateRendering?
    weak var viewModelBinder: KeywordsViewModelBinding?
    
    // MARK: - Private Properties
    
    private var possibleAnswers = [QuizViewData.Item]() {
        didSet {
            countRightAnswersUseCase = CountRightAnswersUseCase(possibleAnswers: possibleAnswers)
        }
    }
    private var bottomLeftTextString: String {
        return String(format: "%02d", safeNumberOfRightAnswers) + "/" + String(format: "%02d", possibleAnswers.count)
    }
    
    // MARK: - Computed Properties
    
    private var safeNumberOfRightAnswers: Int {
        return numberOfRightAnswers ?? 0
    }
    private var userDidWin: Bool {
        return safeNumberOfRightAnswers > 0 && safeNumberOfRightAnswers == possibleAnswers.count
    }
    
    // MARK: - View Properties / Binding
    
    private var viewTitle: String? {
        didSet {
            viewModelBinder?.viewTitleDidChange(viewTitle)
        }
    }
    private var textFieldPlaceholder: String? {
        didSet {
            viewModelBinder?.textFieldPlaceholderDidChange(textFieldPlaceholder)
        }
    }
    private var bottomRightText: String? {
        didSet {
            viewModelBinder?.bottomRightTextDidChange(bottomRightText)
        }
    }
    private var bottomLeftText: String? {
        didSet {
            viewModelBinder?.bottomLeftTextDidChange(bottomLeftTextString)
        }
    }
    private var bottomButtonTitle: String? {
        didSet {
            viewModelBinder?.bottomButtonTitleDidChange(bottomButtonTitle)
        }
    }
    private var numberOfRightAnswers: Int? {
        willSet {
            cleanTextFieldIfNeeededWhenNumberOfRightAnswersWillSet(newValue: newValue)
        }
        didSet {
            viewModelBinder?.bottomLeftTextDidChange(bottomLeftTextString)
            showWinnerModalIfNeeded()
        }
    }
    
    // MARK: - Initialization
    
    init(
        timerPeriod: Int = 300,
        countDownTimer: CountDownTimerProvider = CountDownTimer(),
        fetchQuizUseCase: FetchQuizUseCaseProvider,
        countDownFormatter: CountDownFormatting = CountDownFormatter(),
        countRightAnswersUseCase: CountRightAnswersUseCaseProvider = CountRightAnswersUseCase()
    ) {
        self.timerPeriod = timerPeriod
        self.countDownTimer = countDownTimer
        self.fetchQuizUseCase = fetchQuizUseCase
        self.countDownFormatter = countDownFormatter
        self.countRightAnswersUseCase = countRightAnswersUseCase
    }
    
    // MARK: - Display Logic
    
    func onViewDidLoad() {
        viewTitle = ""
        textFieldPlaceholder = "Insert Word"
        bottomButtonTitle = "Start"
        bottomLeftText = bottomLeftTextString
        bottomRightText = countDownFormatter.formatToMinutes(from: timerPeriod)
        loadQuizData()
    }
    
    var numberOfAnswers: Int {
        return possibleAnswers.count
    }
    
    func answerItem(at index: Int) -> QuizViewData.Item? {
        guard index < possibleAnswers.count else { return nil }
        return possibleAnswers[index]
    }
    
}

// MARK: - KeywordsViewModelBusinessLogic
extension KeywordsViewModel: KeywordsViewModelBusinessLogic {
    
    func loadQuizData() {
        fetchQuizUseCase.execute { [weak self] event in
            switch event.status {
            case let .data(viewData):
                self?.handleViewData(viewData)
            case let .serviceError(serviceError):
                self?.handleServiceError(serviceError)
            case .loading:
                self?.viewStateRenderer?.render(.loading)
            default:
                return
            }
        }
    }
    
    func toggleTimer() {
        if countDownTimer.isRunning {
            resetQuiz()
        } else {
            startTimer()
        }
    }
    
    func resetQuiz() {
        countDownTimer.stop()
        numberOfRightAnswers = 0
        resetTimerInfo()
        loadQuizData()
    }
    
    func verifyTextFieldInput(_ input: String?) {
        guard countDownTimer.isRunning else {
            showYouShouldStartTheTimerErrorModal()
            return
        }
        numberOfRightAnswers = countRightAnswersUseCase.execute(input: input)
    }
    
    // MARK: - FetchQuizUseCase Handlers
    
    private func handleViewData(_ viewData: QuizViewData) {
        viewTitle = viewData.title
        possibleAnswers = viewData.items
        bottomLeftText = "00/\(viewData.items.count)"
        viewStateRenderer?.render(.content)
    }
    
    private func handleServiceError(_ error: Error) {
        let filler = ViewFiller(title: "Ooops!", subtitle: "Something wrong has happened")
        viewStateRenderer?.render(.error(withFiller: filler))
    }
    
    // MARK: - Timer Logic
    
    private func startTimer() {
        
        bottomButtonTitle = "Reset"
        
        let onTick: ((Int) -> Void) = { [weak self] timeLeft in
            self?.bottomRightText = self?.countDownFormatter.formatToMinutes(from: timeLeft)
        }
        
        let onFinish: (() -> Void) = { [weak self] in
            self?.handleTimerFinish()
        }
        
        countDownTimer.dispatch(
            forTimePeriodInSeconds: timerPeriod,
            timeInterval: 1.0,
            onTick: onTick,
            onFinish: onFinish
        )
        
    }
    
    private func handleTimerFinish() {
        if userDidWin {
            showWinnerModal()
        } else {
            showTimeIsUpModal()
        }
        resetTimerInfo()
    }
    
    private func resetTimerInfo() {
        bottomButtonTitle = "Start"
        bottomRightText = countDownFormatter.formatToMinutes(from: timerPeriod)
    }
    
    // MARK: - verifyTextFieldInput Logic
    
    private func cleanTextFieldIfNeeededWhenNumberOfRightAnswersWillSet(newValue: Int?) {
        guard let newValue = newValue, let currentValue = numberOfRightAnswers else { return }
        if newValue >= currentValue {
            viewModelBinder?.textFieldShouldReset()
        }
    }
    
    // MARK: - Modals
    
    private func showTimeIsUpModal() {
        let title = "Time finished"
        let subtitle = "Sorry, time is up! You got \(safeNumberOfRightAnswers) out of \(possibleAnswers.count) answers."
        let buttonText = "Try Again"
        let modalData = SimpleModalViewData(
            title: title,
            subtitle: subtitle,
            buttonText: buttonText
        )
        viewModelBinder?.showTimerFinishedModalWithData(modalData)
    }
    
    private func showWinnerModal() {
    
        countDownTimer.stop()
        
        let title = "Congratulations"
        let subtitle = "Good job! You found all the answers on time. Keep up with the great work."
        let buttonText = "Play Again"
        let modalData =  SimpleModalViewData(
            title: title,
            subtitle: subtitle,
            buttonText: buttonText
        )
        
        viewModelBinder?.showWinnerModalWithData(modalData)
    }
    
    private func showWinnerModalIfNeeded() {
        if userDidWin && countDownTimer.isRunning {
            showWinnerModal()
        }
    }
    
    private func showYouShouldStartTheTimerErrorModal() {
        let modalData = SimpleModalViewData(title: "Ops!", subtitle: "You need to start the timer for your points to count.")
        viewModelBinder?.showErrorModalWithData(modalData)
    }
    
}
