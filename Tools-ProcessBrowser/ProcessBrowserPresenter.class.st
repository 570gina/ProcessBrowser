"
ProcessBrowserPresenter new openWithSpec 
"
Class {
	#name : #ProcessBrowserPresenter,
	#superclass : #ComposablePresenter,
	#instVars : [
		'processListPresenter',
		'currentSelectedProcessPresenter',
		'methodPanePresenter',
		'processList',
		'autoUpdateProcess',
		'stackList',
		'selectedProcess'
	],
	#classVars : [
		'SuspendedProcesses',
		'WellKnownProcesses'
	],
	#category : #'Tools-ProcessBrowser'
}

{ #category : #'from legacy' }
ProcessBrowserPresenter class >> cleanUp [
 "Remove terminated processes from my suspended list"

       self suspendedProcesses keysDo: [:ea |
               ea isTerminated ifTrue: [self suspendedProcesses removeKey: ea]]
]

{ #category : #specs }
ProcessBrowserPresenter class >> defaultSpec [
	
	^ SpecColumnLayout composed
		newRow: [:row | 
			row add: #processListPresenter; add: #currentSelectedProcessPresenter];
		newRow: [ :row |
			row add: #methodPanePresenter ];
		yourself.
]

{ #category : #'from legacy' }
ProcessBrowserPresenter class >> initialize [
	"ProcessBrowserPresenter initialize"
	SuspendedProcesses ifNil: [ SuspendedProcesses := IdentityDictionary new ].
	self registerWellKnownProcesses
]

{ #category : #'from legacy' }
ProcessBrowserPresenter class >> nameAndRulesFor: aProcess [ 
	"Answer a nickname and two flags: allow-stop, and allow-debug"
	| rules |
	rules := {nil. true. true}.
	WellKnownProcesses do: [:blockAndRules |
		blockAndRules key value == aProcess 
			ifTrue: [ rules := blockAndRules value value ]].
	rules first ifNil: [ 
		rules at: 1 put: aProcess suspendedContext asString ].
	^ rules
]

{ #category : #building }
ProcessBrowserPresenter class >> open [
	<script>

	ProcessBrowserPresenter new openWithSpec 
]

{ #category : #'from legacy' }
ProcessBrowserPresenter class >> registerWellKnownProcess: aBlockForProcess label: nickname allowStop: allowStop allowDebug: allowDebug [
	"Add an entry to the registry of well known processes. aBlockForProcess
	evaluates to a known process to be identified by nickname, and allowStop
	and allowDebug are flags controlling allowable actions for this process
	in the browser."

	WellKnownProcesses add: aBlockForProcess->[{nickname . allowStop . allowDebug}]
]

{ #category : #'from legacy' }
ProcessBrowserPresenter class >> registerWellKnownProcesses [
	"Associate each well-known process with a nickname and two flags: allow-stop, and allow-debug.
	Additional processes may be added to this list as required"

	WellKnownProcesses := OrderedCollection new.
	self
		registerWellKnownProcess: [  ]
		label: 'no process'
		allowStop: false
		allowDebug: false.
	self
		registerWellKnownProcess: [ Smalltalk lowSpaceWatcherProcess ]
		label: nil
		allowStop: false
		allowDebug: false.
	self
		registerWellKnownProcess: [ WeakArray runningFinalizationProcess ]
		label: nil
		allowStop: false
		allowDebug: false.
	self
		registerWellKnownProcess: [ Processor backgroundProcess ]
		label: nil
		allowStop: false
		allowDebug: false.
	self
		registerWellKnownProcess: [ InputEventFetcher default fetcherProcess ]
		label: nil
		allowStop: false
		allowDebug: false.
	self
		registerWellKnownProcess: [ UIManager default uiProcess ]
		label: nil
		allowStop: false
		allowDebug: false.
	self
		registerWellKnownProcess: [ Smalltalk globals at: #SoundPlayer ifPresent: [ :sp | sp playerProcess ] ]
		label: 'the Sound Player'
		allowStop: false
		allowDebug: false.
	self
		registerWellKnownProcess: [ Smalltalk globals at: #CPUWatcher ifPresent: [ :cw | cw currentWatcherProcess ] ]
		label: 'the CPUWatcher'
		allowStop: false
		allowDebug: false.
		
	self
		registerWellKnownProcess: [ Delay schedulingProcess ]
		label: nil
		allowStop: false
		allowDebug: false
]

{ #category : #'from legacy' }
ProcessBrowserPresenter class >> suspendedProcesses [
	"Answer a collection of processes that my instances have suspended.  
	This is so that they don't get garbage collected."
	^ SuspendedProcesses
		ifNil: [SuspendedProcesses := IdentityDictionary new]
]

{ #category : #'from legacy' }
ProcessBrowserPresenter class >> unregisterWellKnownProcess: aProcess [
	"Remove the first registry entry that matches aProcess. Use
	with caution if more than one registry entry may match aProcess."

	"self unregisterWellKnownProcess: Smalltalk lowSpaceWatcherProcess"

	WellKnownProcesses detect: [ :e | e key value == aProcess ] ifFound: [ :entry | WellKnownProcesses remove: entry ]
]

{ #category : #building }
ProcessBrowserPresenter >> changeStackListTo: aCollection [ 

        stackList := aCollection.
        self changed: #stackList.
]

{ #category : #accessing }
ProcessBrowserPresenter >> currentSelectedProcessPresenter [
	^ currentSelectedProcessPresenter
]

{ #category : #accessing }
ProcessBrowserPresenter >> currentSelectedProcessPresenter: anObject [
	currentSelectedProcessPresenter := anObject
]

{ #category : #inspecting }
ProcessBrowserPresenter >> explorePointers [
	| saved |
	selectedProcess ifNil: [ ^ self ].
	saved := selectedProcess.
	[ selectedProcess := nil.
	(Smalltalk tools hasToolNamed: #pointerExplorer)
		ifTrue: [ Smalltalk tools pointerExplorer openOn: saved ]
		ifFalse: [ self inspectPointers ] ]
		     ensure: [ selectedProcess := saved ]
]

{ #category : #inspecting }
ProcessBrowserPresenter >> exploreProcess [
	selectedProcess inspect
]

{ #category : #api }
ProcessBrowserPresenter >> extent [
	^1000@600
]

{ #category : #initialization }
ProcessBrowserPresenter >> initialize [
	self initializeProcessList.
	super initialize.
	autoUpdateProcess := false.
	
]

{ #category : #initialization }
ProcessBrowserPresenter >> initializePresenter [
	| suspendedContext |
	processListPresenter
		whenSelectedItemChanged: [ :process | 
			process
				ifNotNil: [ selectedProcess := process.
					suspendedContext := process suspendedContext.
					suspendedContext
						ifNil: [ self changeStackListTo: nil ]
						ifNotNil: [ self changeStackListTo: (suspendedContext stackOfSize: 20) ].
					methodPanePresenter text: ''.
					currentSelectedProcessPresenter items: self stackList; displayBlock: #asString.
					currentSelectedProcessPresenter resetSelection ] ].
			
	currentSelectedProcessPresenter
		whenSelectedItemChanged: [ :process | 
			process
				ifNotNil: [ methodPanePresenter
						text: process sourceCode;
						behavior: process methodClass ] ]
]

{ #category : #initialization }
ProcessBrowserPresenter >> initializeProcessList [
	
 	Smalltalk garbageCollectMost.
	processList := Process allSubInstances
				reject: [:each | each isTerminated].
	processList := processList
				sort: [:a :b | a priority >= b priority].
	processList := WeakArray withAll: processList.
]

{ #category : #initialization }
ProcessBrowserPresenter >> initializeWidgets [
	processListPresenter := self newList.
	currentSelectedProcessPresenter := self newList.
	methodPanePresenter := self newCode.
	methodPanePresenter aboutToStyle: true.
	processListPresenter items: processList; displayBlock: [ :process | self processNameOf: process ].
	self focusOrder
		add: processListPresenter;
		add: currentSelectedProcessPresenter;
		add: methodPanePresenter
]

{ #category : #inspecting }
ProcessBrowserPresenter >> inspectPointers [
	| tc pointers |
	selectedProcess ifNil: [ ^ self ].
	tc := thisContext.
	pointers := selectedProcess pointersToExcept: { self processListPresenter. tc. self}.
	pointers ifEmpty: [ ^ self ].
	pointers inspectWithLabel: 'Objects pointing to ' , selectedProcess browserPrintString
]

{ #category : #inspecting }
ProcessBrowserPresenter >> inspectProcess [
	selectedProcess inspect
]

{ #category : #accessing }
ProcessBrowserPresenter >> methodPanePresenter [
	^ methodPanePresenter
]

{ #category : #accessing }
ProcessBrowserPresenter >> methodPanePresenter: anObject [
	methodPanePresenter := anObject
]

{ #category : #building }
ProcessBrowserPresenter >> nameAndRulesFor: aProcess [ 
	"Answer a nickname and two flags: allow-stop, and allow-debug"
	aProcess == autoUpdateProcess ifTrue: [ ^{'my auto-update process'. true. true} ].
	^self class nameAndRulesFor: aProcess 

]

{ #category : #building }
ProcessBrowserPresenter >> prettyNameForProcess: aProcess [ 
	| nameAndRules |
	aProcess ifNil: [ ^'<nil>' ].
	nameAndRules := self nameAndRulesFor: aProcess.
	^ aProcess browserPrintStringWith: nameAndRules first
]

{ #category : #accessing }
ProcessBrowserPresenter >> processListPresenter [
	^ processListPresenter
]

{ #category : #accessing }
ProcessBrowserPresenter >> processListPresenter: anObject [
	processListPresenter := anObject
]

{ #category : #building }
ProcessBrowserPresenter >> processNameOf: aProcess [
	"since processList is a WeakArray, we have to strengthen the result"

	| tally percent |
	tally := CPUWatcher
		ifNotNil: [ CPUWatcher current ifNotNil: [ CPUWatcher current tally ] ].
		
	percent := tally
		ifNotNil: [ (((tally occurrencesOf: aProcess) * 100.0 / tally size roundTo: 1)
				asString padLeftTo: 2) , '% ' ]
		ifNil: [ '' ].
	^ percent , (self prettyNameForProcess: aProcess)
]

{ #category : #building }
ProcessBrowserPresenter >> stackList [
	^ stackList ifNil: [ #() ]
]

{ #category : #api }
ProcessBrowserPresenter >> title [ 

	^ 'Process Browser'
]
