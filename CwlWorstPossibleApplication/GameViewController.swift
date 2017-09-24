//
//  GameViewController.swift
//  CwlWorstPossibleApplication
//
//  Created by Matt Gallagher on 2017/09/01.
//  Copyright © 2017 Matt Gallagher. All rights reserved.
//

import UIKit
import GameKit

class GameViewController: UIViewController {
	static let gameWidth: Int = 10
	static let gameHeight: Int = 10
	static let initialMineCount: Int = 15
	
	@IBOutlet var squaresToClear: UILabel?
	@IBOutlet var flagMode: UISwitch?
	@IBOutlet var newGameButton: UIButton?
	
	var squares: Array<SquareView> = []
	var nonMineSquaresRemaining = 0 { didSet {
		if nonMineSquaresRemaining == -1 {
			squaresToClear?.text = NSLocalizedString("Boom... you lose!", comment: "")
		} else if nonMineSquaresRemaining == 0 {
			squaresToClear?.text = NSLocalizedString("None... you win!", comment: "")
		} else {
			squaresToClear?.text = "\(nonMineSquaresRemaining)"
		}
	} }
	
	func loadGame(newSquares: Array<SquareView>, remaining: Int) {
		squares.forEach { $0.removeFromSuperview() }
		squares = newSquares
		nonMineSquaresRemaining = remaining
		for s in squares {
			self.view.addSubview(s)
			s.addTarget(self, action: #selector(squareTapped(_:)), for: .primaryActionTriggered)
		}
	}
	
	@IBAction func startNewGame() {
		loadGame(newSquares: newMineField(mineCount: GameViewController.initialMineCount), remaining: GameViewController.gameWidth * GameViewController.gameHeight - GameViewController.initialMineCount)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		newGameButton?.layer.cornerRadius = 8
		startNewGame()
	}
	
	@objc func squareTapped(_ sender: Any?) {
		guard let s = sender as? SquareView, nonMineSquaresRemaining > 0 else { return }
		
		if flagMode?.isOn == true, s.covering != .uncovered {
			s.covering = s.covering == .covered ? .flagged : .covered
			return
		} else if s.covering == .flagged {
			return
		}
		
		if s.isMine {
			s.covering = .uncovered
			nonMineSquaresRemaining = -1
			return
		}
		
		nonMineSquaresRemaining -= uncover(squares: &squares, index: s.location)
	}
	
	override func viewDidLayoutSubviews() {
		let availableWidth = self.view.frame.size.width
		let usedWidth = CGFloat(SquareView.squareSize + 2) * CGFloat(GameViewController.gameWidth)
		let availableHeight = self.view.frame.size.height
		let usedHeight = CGFloat(SquareView.squareSize + 2) * CGFloat(GameViewController.gameHeight)
		for y in 0..<GameViewController.gameHeight {
			for x in 0..<GameViewController.gameWidth {
				let s = squares[x + y * GameViewController.gameWidth]
				s.frame.origin = CGPoint(x: 0.5 * (availableWidth - usedWidth) + CGFloat(x) * CGFloat(SquareView.squareSize + 2) + 1, y: 0.5 * (availableHeight - usedHeight) + CGFloat(y) * CGFloat(SquareView.squareSize + 2) + 1)
			}
		}
	}
	
	override func decodeRestorableState(with coder: NSCoder) {
		super.decodeRestorableState(with: coder)
		if coder.containsValue(forKey: String.flagModeKey) {
			flagMode?.isOn = coder.decodeBool(forKey: String.flagModeKey)
		}
		
		if let squaresArray = coder.decodeObject(forKey: String.squaresKey) as? Array<Dictionary<String, Any>>, coder.containsValue(forKey: String.remainingKey) {
			do {
				let newSquares = try squaresArray.map { try SquareView(fromDictionary: $0) }
				loadGame(newSquares: newSquares, remaining: coder.decodeInteger(forKey: String.remainingKey))
			} catch {
				startNewGame()
			}
		}
	}
	
	override func encodeRestorableState(with coder: NSCoder) {
		super.encodeRestorableState(with: coder)
		coder.encode(squares.map { $0.toDictionary() } as Array<Dictionary<String, Any>>, forKey: String.squaresKey)
		coder.encode(nonMineSquaresRemaining as Int, forKey: String.remainingKey)
		coder.encode((flagMode?.isOn == true) as Bool, forKey: String.flagModeKey)
	}
}

fileprivate extension String {
	static let squaresKey = "squares"
	static let remainingKey = "remaining"
	static let flagModeKey = "flagMode"
}

func newMineField(mineCount: Int) -> Array<SquareView> {
	let random = GKRandomDistribution(randomSource: GKRandomSource(), lowestValue: 0, highestValue: GameViewController.gameWidth * GameViewController.gameHeight - 1)
	var squares = Array<SquareView>()
	for l in 0..<(GameViewController.gameWidth * GameViewController.gameHeight) {
		squares.append(SquareView(location: l))
	}
	
	for _ in 1...mineCount {
		var n = 0
		repeat {
			n = random.nextInt()
		} while squares[n].isMine
		squares[n].isMine = true
		iterateAdjacent(squares: &squares, index: n) { (ss: inout Array<SquareView>, index: Int) in
			if !ss[index].isMine {
				ss[index].adjacent += 1
			}
		}
	}
	return squares
}

func uncover(squares: inout Array<SquareView>, index: Int) -> Int {
	guard squares[index].covering == .covered else { return 0 }
	
	squares[index].covering = .uncovered
	
	if squares[index].adjacent == 0 {
		var cleared = 1
		iterateAdjacent(squares: &squares, index: index) { (ss: inout Array<SquareView>, i: Int) in
			cleared += uncover(squares: &ss, index: i)
		}
		return cleared
	} else {
		return 1
	}
}

func iterateAdjacent(squares: inout Array<SquareView>, index n: Int, process: (inout Array<SquareView>, Int) -> ()) {
	let isOnLeftEdge = n % GameViewController.gameWidth == 0
	let isOnRightEdge = n % GameViewController.gameWidth == GameViewController.gameHeight - 1
	
	if n >= GameViewController.gameWidth {
		if !isOnLeftEdge { process(&squares, n - GameViewController.gameWidth - 1) }
		process(&squares, n - GameViewController.gameWidth)
		if !isOnRightEdge { process(&squares, n - GameViewController.gameWidth + 1) }
	}
	
	if !isOnLeftEdge { process(&squares, n - 1) }
	if !isOnRightEdge { process(&squares, n + 1) }
	
	if n < GameViewController.gameWidth * (GameViewController.gameHeight - 1) {
		if !isOnLeftEdge { process(&squares, n + GameViewController.gameWidth - 1) }
		process(&squares, n + GameViewController.gameWidth)
		if !isOnRightEdge { process(&squares, n + GameViewController.gameWidth + 1) }
	}
}