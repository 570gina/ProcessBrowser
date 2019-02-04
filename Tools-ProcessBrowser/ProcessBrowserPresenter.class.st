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
		'stackList'
	],
	#classVars : [
		'SuspendedProcesses',
		'WellKnownProcesses'
	],
	#category : #'Tools-ProcessBrowser'
}

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
ProcessBrowserPresenter class >> openNewOne [
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
        self changed: #stackNameList.
]

{ #category : #accessing }
ProcessBrowserPresenter >> currentSelectedProcessPresenter [
	^ currentSelectedProcessPresenter
]

{ #category : #accessing }
ProcessBrowserPresenter >> currentSelectedProcessPresenter: anObject [
	currentSelectedProcessPresenter := anObject
]

{ #category : #initialization }
ProcessBrowserPresenter >> initialize [
	self initializeProcessList.
	super initialize.
	autoUpdateProcess := false.
	
]

{ #category : #initialization }
ProcessBrowserPresenter >> initializePresenter [
	|suspendedContext|
	processListPresenter whenSelectionIndexChanged: [ :i |
		(i>0) 
			ifTrue: [
				suspendedContext := (processList at: i) suspendedContext.
				suspendedContext
					ifNil: [self changeStackListTo: nil]
					ifNotNil: [self changeStackListTo: (suspendedContext stackOfSize: 20)].
				methodPanePresenter text: ''.
				currentSelectedProcessPresenter items: self stackNameList.
				currentSelectedProcessPresenter resetSelection.			
			]
	].
	
	currentSelectedProcessPresenter whenSelectionIndexChanged: [ :i |
		(i>0) ifTrue: [ 
			methodPanePresenter 
				text: (stackList at:i) sourceCode; 
				behavior: Class.
			]]
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
	currentSelectedProcessPresenter  := self newList.
	methodPanePresenter := self newText.
	methodPanePresenter
		aboutToStyle: true;
		isCodeCompletionAllowed: true.	
	processListPresenter items: self processNameList.
	
	self focusOrder 
		add: processListPresenter;
		add: currentSelectedProcessPresenter;
		add: methodPanePresenter.
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
ProcessBrowserPresenter >> processNameList [
	"since processList is a WeakArray, we have to strengthen the result"
	| tally |
	tally := CPUWatcher ifNotNil: [ CPUWatcher current ifNotNil: [ CPUWatcher current tally ] ].
	
	^ (processList asOrderedCollection copyWithout: nil)
		collect: [ :each | 
			| percent |
			percent := tally
				ifNotNil: [ (((tally occurrencesOf: each) * 100.0 / tally size roundTo: 1) asString padLeftTo: 2) , '% ' ]
				ifNil: [ '' ].
			percent , (self prettyNameForProcess: each) ]
]

{ #category : #building }
ProcessBrowserPresenter >> stackNameList [
	^ stackList
		ifNil: [#()]
		ifNotNil: [stackList collect: [:each | each asString]]
]

{ #category : #api }
ProcessBrowserPresenter >> title [ 

	^ 'Process Browser'
]
