Class {
	#name : #SpecProcessBrowserTest,
	#superclass : #TestCase,
	#instVars : [
		'browser'
	],
	#category : #'Tools-ProcessBrowser-Tests'
}

{ #category : #'set up' }
SpecProcessBrowserTest >> createANewProcess [
	| semaphore newProcess |
	"Create a new process that will stay alive"
	semaphore := Semaphore new.
	newProcess := [ semaphore signal.
	Semaphore new wait ] fork.
	semaphore wait.
		"Wait for the process above to have started, just to be sure"
	^ newProcess
]

{ #category : #'set up' }
SpecProcessBrowserTest >> setUp [
	"Hooks that subclasses may override to define the fixture of test."

	browser := SpecProcessBrowser new
]

{ #category : #tests }
SpecProcessBrowserTest >> testAutoUpdateDoesNotShareStateInTwoProcessBrowsers [
	| otherBrowser |
	otherBrowser := SpecProcessBrowser new.
		self assert: browser isAutoUpdating equals: otherBrowser isAutoUpdating.
	browser startAutoUpdate.
	self deny: browser isAutoUpdating equals: otherBrowser isAutoUpdating.
	browser stopAutoUpdate
]

{ #category : #tests }
SpecProcessBrowserTest >> testCreateANewProcess [
	| processList oldProcessListSize newProcess oldProcessList |
	"Build the list of all the instances of Process"
	oldProcessList := Process allSubInstances
		reject: [ :each | each isTerminated ].
	"Store how many processes there are"
	oldProcessListSize := oldProcessList size.

	"Create a new Process"
	newProcess := self createANewProcess.

	"Rebuild the list of all instances of Process"
	processList := Process allSubInstances
		reject: [ :each | each isTerminated ].

	"Check that the size of this new process list is one greater than the stored value"
	self assert: processList size equals: oldProcessListSize + 1.

	"Check that the new process list does indeed include the new process we just created"
	self assert: (processList includes: newProcess).
]

{ #category : #tests }
SpecProcessBrowserTest >> testFindTheContext [
	| newProcess found |
	"Create a new Process"
	newProcess := self createANewProcess.
	browser searchString: 'semaphore signal'.
	browser updateProcessList.
	found := browser nextContext.
	self assert: found.
	newProcess terminate.
	browser updateProcessList.
	found := browser nextContext.
	self deny: found
]

{ #category : #tests }
SpecProcessBrowserTest >> testProcessesAreArrangedAccordingToPriority [
	browser processListPresenter items allButFirst
		inject: browser processListPresenter items first
		into: [ :front :process | 
			self assert: front priority >= process priority.
			process ]
]

{ #category : #tests }
SpecProcessBrowserTest >> testTerminateTheProcess [
	| newProcess |
	"Create a new Process"
	newProcess := self createANewProcess.
	browser updateProcessList.
	self
		assert: (browser processListPresenter items includes: newProcess).
	browser processListPresenter selectItem: newProcess.
	browser terminateProcess.
	self deny: (browser processListPresenter items includes: newProcess)
]

{ #category : #tests }
SpecProcessBrowserTest >> testUpdateListButtonIsClicked [
	| newProcess oldProcessList |
	oldProcessList := browser processListPresenter items.

	"Create a new Process"
	newProcess := self createANewProcess.
	browser updateButton performAction.
	self deny: browser processListPresenter items equals: oldProcessList.
	"Check that the new process list does indeed include the new process we just created"
	self
		assert: (browser processListPresenter items includes: newProcess).
]

{ #category : #tests }
SpecProcessBrowserTest >> testUpdateListButtonIsNotClicked [
	| newProcess oldProcessList |
	oldProcessList := browser processListPresenter items.

	"Create a new Process"
	newProcess := self createANewProcess.
	self
		assert: browser processListPresenter items
		equals: oldProcessList.
	"Check that the new process list does not include the new process we just created"
	self deny: (browser processListPresenter items includes: newProcess).

]
