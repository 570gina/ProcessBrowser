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
		'autoUpdateProcess',
		'processList',
		'stackList',
		'selectedProcess',
		'selectedContext',
		'selectedClass',
		'selectedSelector',
		'startedCPUWatcher',
		'keyEventsDict',
		'deferredMessageRecipient'
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

{ #category : #menu }
ProcessBrowserPresenter class >> menuProcessList: aBuilder [
	<contextMenu>
	<processBrowserProcessListMenu>
	| target selectedProcess |
	target := aBuilder model.
	selectedProcess := target selectedProcess.
	selectedProcess
		ifNotNil: [ | nameAndRules |
			nameAndRules := target nameAndRulesForSelectedProcess.
			(aBuilder item: #Inspect)
				keyText: 'i';
				selector: #inspectProcess.
			(aBuilder item: #Explore)
				keyText: 'I';
				selector: #exploreProcess.
			(aBuilder item: #'Inspect Pointers')
				keyText: 'P';
				selector: #inspectPointers.
			(Smalltalk globals includesKey: #PointerExplorer)
				ifTrue: [ (aBuilder item: #'Explore pointers')
						keyText: 'e';
						selector: #explorePointers ].
			nameAndRules second
				ifTrue: [ (aBuilder item: #Terminate)
						keyText: 't';
						selector: #terminateProcess.
					selectedProcess isSuspended
						ifTrue: [ (aBuilder item: #Resume)
								keyText: 'r';
								selector: #resumeProcess ]
						ifFalse: [ (aBuilder item: #Suspend)
								keyText: 's';
								selector: #suspendProcess ] ].
			nameAndRules third
				ifTrue: [ (aBuilder item: #'Change priority')
						keyText: 'p';
						selector: #changePriority.
					(aBuilder item: #Debug)
						keyText: 'd';
						selector: #debugProcess ].
			(aBuilder item: #'Profile messages')
				keyText: 'm';
				selector: #messageTally.
			(selectedProcess suspendingList isKindOf: Semaphore)
				ifTrue: [ (aBuilder item: #'Signal Semaphore')
						keyText: 'S';
						selector: #signalSemaphore ].
			(aBuilder item: #'Full stack')
				keyText: 'k';
				selector: #moreStack;
				withSeparatorAfter ].
	(aBuilder item: #'Find context...')
		keyText: 'f';
		selector: #findContext.
	(aBuilder item: #'Find again')
		keyText: 'g';
		selector: #nextContext;
		withSeparatorAfter.
	"(aBuilder
		item:
		(target isAutoUpdating
		ifTrue: [ #'Turn off auto-update' ]
		ifFalse: [ #'Turn on auto-update' ]))
		keyText: 'a';
		selector: #toggleAutoUpdate."
	(aBuilder item: #'Update list')
		keyText: 'u';
		selector: #updateProcessList.
	Smalltalk globals
		at: #CPUWatcher
		ifPresent: [ :pw | 
			aBuilder withSeparatorAfter.
			pw isMonitoring
				ifTrue: [ (aBuilder item: #'Stop CPUWatcher') selector: #stopCPUWatcher ]
				ifFalse: [ (aBuilder item: #'Start CPUWatcher') selector: #startCPUWatcher ] ]
]

{ #category : #menu }
ProcessBrowserPresenter class >> menuStackList: aBuilder [
	<contextMenu>
	<processBrowserStackListMenu>
	(aBuilder item: #'Inspect context')
		keyText: 'c';
		selector: #inspectContext.
	(aBuilder item: #'Explore context')
		keyText: 'C';
		selector: #exploreContext;
		withSeparatorAfter.
	(aBuilder item: #'Inspect receiver')
		keyText: 'i';
		selector: #inspectReceiver.
	(aBuilder item: #'Explore receiver')
		keyText: 'I';
		selector: #exploreReceiver;
		withSeparatorAfter.
	(aBuilder item: #Browse)
		keyText: 'b';
		selector: #browseContext
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
ProcessBrowserPresenter class >> terminateProcess: aProcess [
	aProcess ifNotNil: [
		self suspendedProcesses
			removeKey: aProcess
			ifAbsent: [].
		aProcess terminate
	].
]

{ #category : #'from legacy' }
ProcessBrowserPresenter class >> unregisterWellKnownProcess: aProcess [
	"Remove the first registry entry that matches aProcess. Use
	with caution if more than one registry entry may match aProcess."

	"self unregisterWellKnownProcess: Smalltalk lowSpaceWatcherProcess"

	WellKnownProcesses detect: [ :e | e key value == aProcess ] ifFound: [ :entry | WellKnownProcesses remove: entry ]
]

{ #category : #'stack list' }
ProcessBrowserPresenter >> browseContext [
	selectedContext ifNil: [ ^ self ]. 
	self selectedClass.
	self selectedSelector.
	Smalltalk tools browser openOnClass: selectedClass selector: selectedSelector.
]

{ #category : #'process actions' }
ProcessBrowserPresenter >> changePriority [
	| str newPriority nameAndRules |
	nameAndRules := self nameAndRulesForSelectedProcess.
	nameAndRules third
		ifFalse: [self inform: 'Nope, won''t change priority of ' , nameAndRules first.
			^ self].
	str := UIManager default 
				request: 'New priority' 
		  initialAnswer: selectedProcess priority asString.
	str ifNil: [str := String new].
	newPriority := str asNumber asInteger.
	newPriority
		ifNil: [^ self].
	(newPriority < 1
			or: [newPriority > Processor highestPriority])
		ifTrue: [self inform: 'Bad priority'.
			^ self].
	self class setProcess: selectedProcess toPriority: newPriority.
	self updateProcessList
]

{ #category : #'stack list' }
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

{ #category : #'process actions' }
ProcessBrowserPresenter >> debugProcess [
	| nameAndRules |
	nameAndRules := self nameAndRulesForSelectedProcess.
	nameAndRules third
		ifFalse: [self inform: 'Nope, won''t debug ' , nameAndRules first.
			^ self].
	self class debugProcess: selectedProcess.
]

{ #category : #accessing }
ProcessBrowserPresenter >> deferredMessageRecipient: anObject [
	deferredMessageRecipient := anObject
]

{ #category : #accessing }
ProcessBrowserPresenter >> doItContext [
	^selectedContext
]

{ #category : #accessing }
ProcessBrowserPresenter >> doItReceiver [
	^selectedContext ifNil: [ selectedProcess ] ifNotNil: [ selectedContext receiver ]
]

{ #category : #shortcuts }
ProcessBrowserPresenter >> ensureKeyBindingsFor: aWidget [

	super ensureKeyBindingsFor: aWidget.
	
	self registerStackListShortcuts: currentSelectedProcessPresenter.
]

{ #category : #inspecting }
ProcessBrowserPresenter >> exploreContext [
	selectedContext inspect
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

{ #category : #inspecting }
ProcessBrowserPresenter >> exploreReceiver [
	selectedContext ifNotNil: [ selectedContext receiver inspect ]
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
					selectedClass := selectedSelector := nil.
					suspendedContext := process suspendedContext.
					suspendedContext
						ifNil: [ self changeStackListTo: nil ]
						ifNotNil: [ self changeStackListTo: (suspendedContext stackOfSize: 20) ].
					currentSelectedProcessPresenter
						items: self stackList;
						displayBlock: #asString.
					currentSelectedProcessPresenter resetSelection.
					selectedContext := nil.
					methodPanePresenter text: '' ] ].
			
	currentSelectedProcessPresenter
		whenSelectedItemChanged: [ :process | 
			process
				ifNotNil: [ selectedContext := process.
					selectedClass := selectedSelector := nil.
					methodPanePresenter
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
	processListPresenter
		items: processList;
		displayBlock: [ :process | self processNameOf: process ].
	self focusOrder
		add: processListPresenter;
		add: currentSelectedProcessPresenter;
		add: methodPanePresenter.
		
	processListPresenter
		menu: [ :menu :shifted | self processListMenu: menu shifted: shifted ].
	currentSelectedProcessPresenter
		menu: [ :menu :shifted | self stackListMenu: menu shifted: shifted ]
]

{ #category : #inspecting }
ProcessBrowserPresenter >> inspectContext [
	selectedContext inspect
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

{ #category : #inspecting }
ProcessBrowserPresenter >> inspectReceiver [
	selectedContext
		ifNotNil: [selectedContext receiver inspect]
]

{ #category : #shortcuts }
ProcessBrowserPresenter >> keyEventsDict [

	^ keyEventsDict ifNil: [
		keyEventsDict := Dictionary newFromPairs:  #(
			$i #inspectProcess
			$I #exploreProcess
			$e #explorePointers
			$P #inspectPointers
			$t #terminateProcess
			$r #resumeProcess
			$s #suspendProcess
			$d #debugProcess
			$p #changePriority
			$m #messageTally
			$f #findContext
			$g #nextContext
			$a #toggleAutoUpdate
			$u #updateProcessList
			$S #signalSemaphore
			$k #moreStack			
			)
		]

]

{ #category : #initialization }
ProcessBrowserPresenter >> mayBeStartCPUWatcher [
	startedCPUWatcher ifTrue: [ self setUpdateCallbackAfter: 7 ].
]

{ #category : #'stack list' }
ProcessBrowserPresenter >> messageTally [
	| secString secs |
	secString := UIManager default request: 'Profile for how many seconds?' initialAnswer: '4'.
	secString ifNil: [secString := String new].
	secs := secString asNumber asInteger.
	(secs isNil
			or: [secs isZero])
		ifTrue: [^ self].
	[ Smalltalk tools timeProfiler spyOnProcess: selectedProcess forMilliseconds: secs * 1000 ] forkAt: selectedProcess priority + 1.
]

{ #category : #accessing }
ProcessBrowserPresenter >> methodPanePresenter [
	^ methodPanePresenter
]

{ #category : #accessing }
ProcessBrowserPresenter >> methodPanePresenter: anObject [
	methodPanePresenter := anObject
]

{ #category : #'process actions' }
ProcessBrowserPresenter >> nameAndRulesFor: aProcess [ 
	"Answer a nickname and two flags: allow-stop, and allow-debug"
	aProcess == autoUpdateProcess ifTrue: [ ^{'my auto-update process'. true. true} ].
	^self class nameAndRulesFor: aProcess 

]

{ #category : #'process actions' }
ProcessBrowserPresenter >> nameAndRulesForSelectedProcess [
	"Answer a nickname and two flags: allow-stop, and allow-debug"
	^self nameAndRulesFor: selectedProcess
]

{ #category : #'process list' }
ProcessBrowserPresenter >> notify: errorString at: location in: aStream [ 
	"A syntax error happened when I was trying to highlight my pc. 
	Raise a signal so that it can be ignored."
	Warning signal: 'syntax error'
]

{ #category : #building }
ProcessBrowserPresenter >> prettyNameForProcess: aProcess [ 
	| nameAndRules |
	aProcess ifNil: [ ^'<nil>' ].
	nameAndRules := self nameAndRulesFor: aProcess.
	^ aProcess browserPrintStringWith: nameAndRules first
]

{ #category : #menu }
ProcessBrowserPresenter >> processListMenu: aMenu shifted: shifted [
	selectedProcess ifNil: [ ^ nil ].
	aMenu addAllFromPragma: 'processBrowserProcessListMenu' target: self.
	^ aMenu
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

{ #category : #menu }
ProcessBrowserPresenter >> registerProcessShortcuts: aWidget [
	aWidget
		bindKeyCombination: $b meta shift toAction: [ self selectedChangeSet ifNotNil:[ self openChangeSetBrowser ]].
]

{ #category : #shortcuts }
ProcessBrowserPresenter >> registerStackListShortcuts: aWidget [

	aWidget bindKeyCombination: $c meta toAction: [ self selectedContext ifNotNil:[ self inspectContext]].
	aWidget bindKeyCombination: $C meta toAction: [ self selectedContext ifNotNil:[ self exploreContext]].
	aWidget bindKeyCombination: $i meta toAction: [ self selectedContext ifNotNil:[ self inspectReceiver]].
	aWidget bindKeyCombination: $I meta toAction: [ self selectedContext ifNotNil:[ self exploreReceiver]].
	aWidget bindKeyCombination: $b meta toAction: [ self selectedContext ifNotNil:[ self browseContext]].
	
]

{ #category : #accessing }
ProcessBrowserPresenter >> selectedClass [
	"Answer the class in which the currently selected context's method was  found."
	^selectedClass
		ifNil: [ selectedClass := selectedContext receiver
				ifNil: [ selectedSelector := selectedContext method selector.
					   selectedContext method methodClass ]
				ifNotNil: [ selectedContext methodClass ]].
]

{ #category : #accessing }
ProcessBrowserPresenter >> selectedClassOrMetaClass [
	^self doItReceiver class
]

{ #category : #accessing }
ProcessBrowserPresenter >> selectedContext [
	^selectedContext
]

{ #category : #accessing }
ProcessBrowserPresenter >> selectedMethod [
	^selectedContext ifNotNil: [ selectedContext method ]
]

{ #category : #accessing }
ProcessBrowserPresenter >> selectedProcess [
	^selectedProcess
]

{ #category : #accessing }
ProcessBrowserPresenter >> selectedSelector [
	"Answer the class in which the currently selected context's method was  
	found."
	^ selectedSelector
		ifNil: [selectedSelector := selectedContext receiver
				ifNil: [selectedClass := selectedContext method methodClass
					   selectedContext method selector]
				ifNotNil: [selectedContext selector]]
]

{ #category : #updating }
ProcessBrowserPresenter >> shoutAboutToStyle: aPluggableShoutMorphOrView [

	selectedContext ifNil: [^false].
	aPluggableShoutMorphOrView classOrMetaClass: self selectedClass.
	^ true
]

{ #category : #'process actions' }
ProcessBrowserPresenter >> signalSemaphore [
	(selectedProcess suspendingList isKindOf: Semaphore)
		ifFalse: [^ self].
	[selectedProcess suspendingList signal] fork.
	(Delay forMilliseconds: 300) wait.
	"Hate to make the UI wait, but it's convenient..."
	self updateProcessList
]

{ #category : #building }
ProcessBrowserPresenter >> stackList [
	^ stackList ifNil: [ #() ]
]

{ #category : #menu }
ProcessBrowserPresenter >> stackListMenu: aMenu shifted: shifted [
	selectedContext ifNil: [ ^ nil ].
	aMenu addAllFromPragma: 'processBrowserStackListMenu' target: self.
	^ aMenu
]

{ #category : #shortcuts }
ProcessBrowserPresenter >> stackListShortcuts: event from: aMorph [
	selectedContext
		ifNotNil: [ 
			event keyString = '<Cmd-c>'
				ifTrue: [ self inspectContext ].
			event keyString = '<Cmd-C>'
				ifTrue: [ self exploreContext ].
			event keyString = '<Cmd-i>'
				ifTrue: [ self inspectReceiver ].
			event keyString = '<Cmd-I>'
				ifTrue: [ self exploreReceiver ].
			event keyString = '<Cmd-b>'
				ifTrue: [ self browseContext ] ]
]

{ #category : #building }
ProcessBrowserPresenter >> terminateProcess [
	| nameAndRules |
	nameAndRules := self nameAndRulesForSelectedProcess.
	nameAndRules second
		ifFalse: [self inform: 'Nope, won''t kill ' , nameAndRules first.
			^ self].
	self class terminateProcess: selectedProcess.	
	self updateProcessList.
]

{ #category : #api }
ProcessBrowserPresenter >> title [ 
	^ 'Process Browser'
]

{ #category : #updating }
ProcessBrowserPresenter >> updateProcessList [
	stackList := nil.
	currentSelectedProcessPresenter
		items: self stackList;
		displayBlock: #asString.
	self initializeProcessList.
	processListPresenter
		items: processList;
		displayBlock: [ :process | self processNameOf: process ].
	selectedContext := nil.
	methodPanePresenter text: ''
]
