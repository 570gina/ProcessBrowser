Class {
	#name : #SpecProcessBrowserTest,
	#superclass : #TestCase,
	#instVars : [
		'ui'
	],
	#category : #'Tools-ProcessBrowser-Tests'
}

{ #category : #running }
SpecProcessBrowserTest >> setUp [
	"Hooks that subclasses may override to define the fixture of test."
	ui := SpecProcessBrowser new.
]

{ #category : #tests }
SpecProcessBrowserTest >> testRawProcessList [
	| processList oldProcessListSize semaphore newProcess  oldProcessList|
    "Build the list of all the instances of Process"
    oldProcessList := Process allSubInstances reject: [ :each | each isTerminated ].
    "Store how many processes there are"
    oldProcessListSize := oldProcessList size.
    
    "Create a new process that will stay alive"
    semaphore := Semaphore new.
    newProcess := [semaphore signal. Semaphore new wait] fork.
    "Wait for the process above to have started, just to be sure"
    semaphore wait.
    
    "Rebuild the list of all instances of Process"
    processList := Process allSubInstances reject: [ :each | each isTerminated ].
    "Check that the size of this new process list is one greater than the stored value"
    self assert: (processList size) equals: oldProcessListSize + 1.
    "Check that the new process list does indeed include the new process we just created"
    self assert: (processList includes: newProcess)
]

{ #category : #tests }
SpecProcessBrowserTest >> testUpdateListButtonIsClicked [
	| newProcess oldProcessListSize semaphore oldProcessList |
	"Build the list of all the instances of Process"
	oldProcessList := ui processList.
	"Store how many processes there are"
	oldProcessListSize := oldProcessList size.

	"Create a new process that will stay alive"
	semaphore := Semaphore new.
	newProcess := [ semaphore signal.
	Semaphore new wait ] fork.
	"Wait for the process above to have started, just to be sure"
	semaphore wait.
	
	ui updateButton performAction.

	"Check that the size of this new process list is one greater than the stored value"
	self assert: ui processList size equals: oldProcessListSize + 1.
	"Check that the new process list does indeed include the new process we just created"
	self assert: (ui processList includes: newProcess)
]
