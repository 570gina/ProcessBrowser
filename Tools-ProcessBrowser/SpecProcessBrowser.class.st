"
SpecProcessBrowser new openWithSpec
"
Class {
	#name : #SpecProcessBrowser,
	#superclass : #ComposablePresenter,
	#instVars : [
		'selectedProcess',
		'selectedContext',
		'processList',
		'processListIndex',
		'stackList',
		'stackListIndex',
		'selectedClass',
		'selectedSelector',
		'searchString',
		'autoUpdateProcess',
		'deferredMessageRecipient',
		'lastUpdate',
		'startedCPUWatcher',
		'keyEventsDict',
		'textModel',
		'processListPresenter',
		'stackListPresenter',
		'textPresenter',
		'autoUpdateButton',
		'updateButton',
		'theCPUWatcherButton',
		'processLabel',
		'stackLabel'
	],
	#classVars : [
		'SuspendedProcesses',
		'WellKnownProcesses'
	],
	#category : #'Tools-ProcessBrowser'
}

{ #category : #initialization }
SpecProcessBrowser class >> cleanUp [
 "Remove terminated processes from my suspended list"

       self suspendedProcesses keysDo: [:ea |
               ea isTerminated ifTrue: [self suspendedProcesses removeKey: ea]]
]

{ #category : #'process control' }
SpecProcessBrowser class >> debugProcess: aProcess [
	self resumeProcess: aProcess.
	aProcess debugWithTitle: 'Interrupted from the Process Browser'.

]

{ #category : #specs }
SpecProcessBrowser class >> defaultSpec [
	^ SpecColumnLayout composed
		newRow: [ :row | 
			row
				add: #processLabel;
				add: #stackLabel ] height: self defaultFont height;
		newRow: [ :row | 
			row
				add: #processListPresenter;
				add: #stackListPresenter ];
		newRow: [ :row | 
			row
				add: #autoUpdateButton;
				add: #updateButton;
				add: #theCPUWatcherButton ] height: self toolbarHeight;
		add: #textPresenter;
		yourself
]

{ #category : #'CPU utilization' }
SpecProcessBrowser class >> dumpPigStackOn: aStream [
	"Must run forked on its own process, so the monitored behavior is not affected too much" 

	| promise tally process depth stack suspendedContext |
	promise := Processor tallyCPUUsageFor: 1 every: 10.
	tally := promise value.
	"WorldState addDeferredUIMessage: [self dumpTallyOnTranscript: tally]."
	aStream nextPutAll: '====Al processes===='; cr.
	self dumpTally: tally on: aStream.
	aStream cr; nextPutAll: '====Process using most CPU===='; cr.
	process := tally sortedCounts first value.
	(100.0 * (tally occurrencesOf: process) / tally size) rounded printOn: aStream.
	aStream
		nextPutAll: ' % ';
		nextPutAll: (process browserPrintStringWith: (self nameAndRulesFor: process) first);
		cr.
	depth := 20.
	stack := process == Processor activeProcess
		ifTrue: [thisContext stackOfSize: depth]
		ifFalse: [suspendedContext := process suspendedContext.
			suspendedContext
				ifNotNil: [suspendedContext stackOfSize: depth]].
	stack 
		ifNil: [ aStream nextPutAll: 'No context'; cr]
		ifNotNil: [
			stack do: [ :c | 
				c printOn: aStream.
				aStream cr]].
]

{ #category : #'CPU utilization' }
SpecProcessBrowser class >> dumpTally: tally on: aStream [
	"tally is from ProcessorScheduler>>tallyCPUUsageFor:
	Dumps lines with percentage of time, hash of process, and a friendly name"

	tally sortedCounts do: [ :assoc | | procName |
		procName := (self nameAndRulesFor: assoc value) first.
		(((assoc key / tally size) * 100.0) roundTo: 1) printOn: aStream.
		aStream
			nextPutAll: '%   ';
			print: assoc value identityHash; space;
			nextPutAll: procName;
			cr.
	]
]

{ #category : #'CPU utilization' }
SpecProcessBrowser class >> dumpTallyOnTranscript: tally [
	"tally is from ProcessorScheduler>>tallyCPUUsageFor:
	Dumps lines with percentage of time, hash of process, and a friendly name"

	self dumpTally: tally on: Transcript.
	Transcript flush.
]

{ #category : #initialization }
SpecProcessBrowser class >> initialize [
	"ProcessBrowser initialize"
	SuspendedProcesses ifNil: [ SuspendedProcesses := IdentityDictionary new ].
	self registerWellKnownProcesses.
]

{ #category : #'process control' }
SpecProcessBrowser class >> isUIProcess: aProcess [
	^ aProcess == UIManager default uiProcess
]

{ #category : #'world menu' }
SpecProcessBrowser class >> menuCommandOn: aBuilder [ 
	<worldMenu> 
	(aBuilder item: #'Spec Process Browser')
		parent: #System;
		order: 0;
		action:[ self open ];
		help: 'Provides a view of all of the processes (threads) executing in Smalltalk.';
		icon: self taskbarIcon.
]

{ #category : #menu }
SpecProcessBrowser class >> menuProcessList: aBuilder [ 
	<contextMenu>
	<processBrowserProcessMenu>

	| target selectedProcess |
	
	target := aBuilder model.
	selectedProcess := target selectedProcess.
	
	selectedProcess
		ifNotNil: [ 
			| nameAndRules |
			nameAndRules := target nameAndRulesForSelectedProcess.
			(aBuilder item: #'Inspect')
				keyText: 'i';
				selector: #inspectProcess.
			(aBuilder item: #'Explore')
				keyText: 'I';
				selector: #exploreProcess.
			(aBuilder item: #'Inspect Pointers')
				keyText: 'P';
				selector: #inspectPointers.
			(Smalltalk globals includesKey: #PointerExplorer)
				ifTrue: [ 
					(aBuilder item: #'Explore pointers')
						keyText: 'e';
						selector: #explorePointers ].
					
			nameAndRules second
				ifTrue: [ 
					(aBuilder item: #'Terminate')
						keyText: 't';
						selector: #terminateProcess.

					selectedProcess isSuspended
						ifTrue: [ 
							(aBuilder item: #'Resume')
								keyText: 'r';
								selector: #resumeProcess ]
						ifFalse: [ 
							(aBuilder item: #'Suspend')
								keyText: 's';
								selector: #suspendProcess ] ].
			
			nameAndRules third
				ifTrue: [ 
					(aBuilder item: #'Change priority')
						keyText: 'p';
						selector: #changePriority.
					(aBuilder item: #'Debug')
						keyText: 'd';
						selector: #debugProcess ].
			
			(aBuilder item: #'Profile messages')
				keyText: 'm';
				selector: #messageTally.

			(selectedProcess suspendingList isKindOf: Semaphore)
				ifTrue: [ 
					(aBuilder item: #'Signal Semaphore')
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

	"(aBuilder item: (target isAutoUpdating
			ifTrue: [ #'Turn off auto-update' ]
			ifFalse: [ #'Turn on auto-update' ]))
		keyText: 'a';
		selector: #toggleAutoUpdate.
	(aBuilder item: #'Update list')
		keyText: 'u';
		selector: #updateProcessList.

	Smalltalk globals 
		at: #CPUWatcher 
		ifPresent: [ :pw | 
			aBuilder withSeparatorAfter.
			pw isMonitoring
				ifTrue: [ 
					(aBuilder item: #'Stop CPUWatcher')
						selector: #stopCPUWatcher ]
				ifFalse: [ 
					(aBuilder item: #'Start CPUWatcher')
						selector: #startCPUWatcher ]]."
]

{ #category : #menu }
SpecProcessBrowser class >> menuStackList: aBuilder [
	<contextMenu>
	<processBrowserStackMenu>
	
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
		
	(aBuilder item: #'Browse')
		keyText: 'b';
		selector: #browseContext.
]

{ #category : #'process control' }
SpecProcessBrowser class >> nameAndRulesFor: aProcess [ 
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

{ #category : #'instance creation' }
SpecProcessBrowser class >> open [
	<script>

	SpecProcessBrowser new openWithSpec 
]

{ #category : #'tools registry' }
SpecProcessBrowser class >> registerToolsOn: registry [
	"Add ourselves to registry. See [Smalltalk tools]" 
	registry register: self as: #processBrowser

]

{ #category : #'process control' }
SpecProcessBrowser class >> registerWellKnownProcess: aBlockForProcess label: nickname allowStop: allowStop allowDebug: allowDebug [
	"Add an entry to the registry of well known processes. aBlockForProcess
	evaluates to a known process to be identified by nickname, and allowStop
	and allowDebug are flags controlling allowable actions for this process
	in the browser."

	WellKnownProcesses add: aBlockForProcess->[{nickname . allowStop . allowDebug}]
]

{ #category : #initialization }
SpecProcessBrowser class >> registerWellKnownProcesses [
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

{ #category : #'process control' }
SpecProcessBrowser class >> resumeProcess: aProcess [
	| priority |
	priority := self suspendedProcesses
				removeKey: aProcess
				ifAbsent: [aProcess priority].
	aProcess priority: priority.
	aProcess suspendedContext ifNotNil: [ aProcess resume ]

]

{ #category : #'process control' }
SpecProcessBrowser class >> setProcess: aProcess toPriority: priority [
	| oldPriority |
	oldPriority := self suspendedProcesses at: aProcess ifAbsent: [ ].
	oldPriority ifNotNil: [ self suspendedProcesses at: aProcess put: priority ].
	aProcess priority: priority.
	^oldPriority
]

{ #category : #'process control' }
SpecProcessBrowser class >> suspendProcess: aProcess [
	| priority |
	priority := aProcess priority.
	self suspendedProcesses at: aProcess put: priority.
	"Need to take the priority down below the caller's
	so that it can keep control after signaling the Semaphore"
	(aProcess suspendingList isKindOf: Semaphore)
		ifTrue: [aProcess priority: Processor lowestPriority.
			aProcess suspendingList signal].
	[aProcess suspend]
		on: Error
		do: [:ex | self suspendedProcesses removeKey: aProcess].
	aProcess priority: priority.

]

{ #category : #'process control' }
SpecProcessBrowser class >> suspendedProcesses [
	"Answer a collection of processes that my instances have suspended.  
	This is so that they don't get garbage collected."
	^ SuspendedProcesses
		ifNil: [SuspendedProcesses := IdentityDictionary new]
]

{ #category : #'CPU utilization' }
SpecProcessBrowser class >> tallyCPUUsageFor: seconds [
	"Compute CPU usage using a 10-msec sample for the given number of seconds,
	then dump the usage statistics on the Transcript. The UI is free to continue, meanwhile"
	"ProcessBrowser tallyCPUUsageFor: 10"
	^self tallyCPUUsageFor: seconds every: 10
]

{ #category : #'CPU utilization' }
SpecProcessBrowser class >> tallyCPUUsageFor: seconds every: msec [
	"Compute CPU usage using a msec millisecond sample for the given number of seconds,
	then dump the usage statistics on the Transcript. The UI is free to continue, meanwhile"
	"ProcessBrowser tallyCPUUsageFor: 10 every: 100"

	| promise |
	promise := Processor tallyCPUUsageFor: seconds every: msec.

	[ | tally |
		tally := promise value.
		UIManager default defer: [ self dumpTallyOnTranscript: tally ].
	] fork.
]

{ #category : #icons }
SpecProcessBrowser class >> taskbarIconName [
	"Answer the icon for the receiver in a task bar."

	^#processBrowserIcon
]

{ #category : #'process control' }
SpecProcessBrowser class >> terminateProcess: aProcess [
	aProcess ifNotNil: [
		self suspendedProcesses
			removeKey: aProcess
			ifAbsent: [].
		aProcess terminate
	].

]

{ #category : #theme }
SpecProcessBrowser class >> theme [
	^ Smalltalk ui theme
]

{ #category : #'process control' }
SpecProcessBrowser class >> unregisterWellKnownProcess: aProcess [
	"Remove the first registry entry that matches aProcess. Use
	with caution if more than one registry entry may match aProcess."

	"self unregisterWellKnownProcess: Smalltalk lowSpaceWatcherProcess"

	WellKnownProcesses detect: [ :e | e key value == aProcess ] ifFound: [ :entry | WellKnownProcesses remove: entry ]
]

{ #category : #'process control' }
SpecProcessBrowser class >> wasProcessSuspendedByProcessBrowser: aProcess [
	^self suspendedProcesses includesKey: aProcess
]

{ #category : #accessing }
SpecProcessBrowser >> autoUpdateButton [
	^ autoUpdateButton
]

{ #category : #'stack list' }
SpecProcessBrowser >> browseContext [
	selectedContext ifNil: [ ^ self ]. 
	Smalltalk tools browser openOnClass: self selectedClass selector: self selectedSelector
]

{ #category : #views }
SpecProcessBrowser >> browsedEnvironment [

	^ Smalltalk globals
]

{ #category : #'process actions' }
SpecProcessBrowser >> changePriority [
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
SpecProcessBrowser >> changeStackListTo: aCollection [ 

        stackList := aCollection.
        self changed: #stackNameList.
        self stackListIndex: 0.
]

{ #category : #'process actions' }
SpecProcessBrowser >> debugProcess [
	| nameAndRules |
	nameAndRules := self nameAndRulesForSelectedProcess.
	nameAndRules third
		ifFalse: [self inform: 'Nope, won''t debug ' , nameAndRules first.
			^ self].
	self class debugProcess: selectedProcess.
]

{ #category : #accessing }
SpecProcessBrowser >> deferredMessageRecipient: anObject [
	deferredMessageRecipient := anObject
]

{ #category : #accessing }
SpecProcessBrowser >> doItContext [
	^selectedContext
]

{ #category : #accessing }
SpecProcessBrowser >> doItReceiver [
	^selectedContext ifNil: [ selectedProcess ] ifNotNil: [ selectedContext receiver ]
]

{ #category : #shortcuts }
SpecProcessBrowser >> ensureKeyBindingsFor: aWidget [

	super ensureKeyBindingsFor: aWidget.
	
	self registerProcessListShortcuts: processListPresenter.
	self registerStackListShortcuts: stackListPresenter.
]

{ #category : #'stack list' }
SpecProcessBrowser >> exploreContext [
	selectedContext inspect
]

{ #category : #'process actions' }
SpecProcessBrowser >> explorePointers [
	| saved |
	selectedProcess ifNil: [ ^ self ].
	saved := selectedProcess.
	[ selectedProcess := nil.
	(Smalltalk tools hasToolNamed: #pointerExplorer)
		ifTrue: [ Smalltalk tools pointerExplorer openOn: saved ]
		ifFalse: [ self inspectPointers ] ]
		     ensure: [ selectedProcess := saved ]
]

{ #category : #'process list' }
SpecProcessBrowser >> exploreProcess [
	selectedProcess inspect
]

{ #category : #'stack list' }
SpecProcessBrowser >> exploreReceiver [
	selectedContext ifNotNil: [ selectedContext receiver inspect ]
]

{ #category : #api }
SpecProcessBrowser >> extent [
	^1000@600
]

{ #category : #'process list' }
SpecProcessBrowser >> findContext [
	| initialProcessIndex initialStackIndex found |
	initialProcessIndex := self processListIndex.
	initialStackIndex := self stackListIndex.
	searchString := UIManager default 
			request: 'Enter a string to search for in the process stack lists'
	  initialAnswer: searchString.
	searchString isEmptyOrNil
		ifTrue: [^ false].
	self processListIndex: 1.
	self stackListIndex: 1.
	found := self nextContext.
	found
		ifFalse: [self processListIndex: initialProcessIndex.
			self stackListIndex: initialStackIndex].
	self updateView.
	^ found
]

{ #category : #updating }
SpecProcessBrowser >> getCPUWatcherState [
	Smalltalk globals
		at: #CPUWatcher
		ifPresent: [ :pw | 
			^(pw isMonitoring)]
]

{ #category : #views }
SpecProcessBrowser >> hasView [
	^self dependents isEmptyOrNil not
]

{ #category : #initialization }
SpecProcessBrowser >> initialize [
	super initialize.
	self class registerWellKnownProcesses.
	stackListIndex := 0.
	searchString := ''.
	lastUpdate := 0.
	textModel :=  RubScrolledTextModel new interactionModel: self; yourself.
	startedCPUWatcher := CPUWatcher cpuWatcherEnabled and: [ self startCPUWatcher ].
	self updateProcessList; processListIndex: 1.

]

{ #category : #initialization }
SpecProcessBrowser >> initializePresenter [
	processListPresenter
		whenSelectedItemChanged: [ :item | 
			self processListIndex: processListPresenter selectedIndex.
			item
				ifNotNil: [ stackListPresenter
						items: self stackList;
						displayBlock: #asString.
					textPresenter text: ''.
					stackListPresenter resetSelection ];
				ifNil: [ stackListPresenter items: #().
					textPresenter text: '' ] ].
	stackListPresenter
		whenSelectedItemChanged: [ :item | 
			self stackListIndex: stackListPresenter selectedIndex.
			item
				ifNotNil: [ textPresenter
						text: selectedContext sourceCode;
						behavior: selectedContext methodClass ];
				ifNil: [ textPresenter text: '' ] ].
	autoUpdateButton
		action: [ self toggleAutoUpdate.
			self isAutoUpdating
				ifTrue: [ autoUpdateButton
						label: 'Stop auto-update';
						icon: (self iconNamed: #stop) ]
				ifFalse: [ autoUpdateButton
						label: 'Start auto-update';
						icon: (self iconNamed: #smallDoIt) ] ].
	updateButton action: [ self updateProcessList ].
	theCPUWatcherButton
		action: [ self getCPUWatcherState
				ifTrue: [ theCPUWatcherButton
						label: 'Start CPUWatcher';
						icon: (self iconNamed: #smallDoIt).
					self stopCPUWatcher ]
				ifFalse: [ theCPUWatcherButton
						label: 'Stop CPUWatcher';
						icon: (self iconNamed: #stop).
					self startCPUWatcher ] ]
]

{ #category : #initialization }
SpecProcessBrowser >> initializeWidgets [
	processLabel := self newLabel.
	processLabel label: '(Priority) Process List'.
	
	stackLabel := self newLabel.
	stackLabel label: 'Stack List'.
		
	processListPresenter := self newList.
	stackListPresenter := self newList.
	
	textPresenter := self newCode.
	textPresenter aboutToStyle: true.
	
	autoUpdateButton := self newButton.
	updateButton := self newButton.
	theCPUWatcherButton := self newButton.
	
	autoUpdateButton
		label: 'Start auto-update';
		icon: (self iconNamed: #smallDoIt).
	updateButton
		label: 'Update list';
		icon: (self iconNamed: #smallUpdate).
		
	self getCPUWatcherState
		ifTrue: [ theCPUWatcherButton
				label: 'Stop CPUWatcher';
				icon: (self iconNamed: #stop) ]
		ifFalse: [ theCPUWatcherButton
				label: 'Start CPUWatcher';
				icon: (self iconNamed: #smallDoIt) ].
			
	self focusOrder
		add: processListPresenter;
		add: stackListPresenter;
		add: textPresenter.
	
	self deferredMessageRecipient: WorldState.
	processListPresenter
		menu: [ :menu :shifted | self processListMenu: menu shifted: shifted ].
	stackListPresenter
		menu: [ :menu :shifted | self stackListMenu: menu shifted: shifted ]
]

{ #category : #'stack list' }
SpecProcessBrowser >> inspectContext [
	selectedContext inspect
]

{ #category : #'process actions' }
SpecProcessBrowser >> inspectPointers [
	| tc pointers |
	selectedProcess ifNil: [ ^ self ].
	tc := thisContext.
	pointers := selectedProcess pointersToExcept: { self processList. tc. self}.
	pointers ifEmpty: [ ^ self ].
	pointers inspectWithLabel: 'Objects pointing to ' , selectedProcess browserPrintString
]

{ #category : #'process list' }
SpecProcessBrowser >> inspectProcess [
	selectedProcess inspect
]

{ #category : #'stack list' }
SpecProcessBrowser >> inspectReceiver [
	selectedContext
		ifNotNil: [selectedContext receiver inspect]
]

{ #category : #updating }
SpecProcessBrowser >> isAutoUpdating [
	^autoUpdateProcess notNil and: [ autoUpdateProcess isSuspended  not ]
]

{ #category : #updating }
SpecProcessBrowser >> isAutoUpdatingPaused [
	^autoUpdateProcess notNil and: [ autoUpdateProcess isSuspended ]
]

{ #category : #'process list' }
SpecProcessBrowser >> keyEventsDict [

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
SpecProcessBrowser >> mayBeStartCPUWatcher [
	startedCPUWatcher ifTrue: [ self setUpdateCallbackAfter: 7 ].

]

{ #category : #'stack list' }
SpecProcessBrowser >> messageTally [
	| secString secs |
	secString := UIManager default request: 'Profile for how many seconds?' initialAnswer: '4'.
	secString ifNil: [secString := String new].
	secs := secString asNumber asInteger.
	(secs isNil
			or: [secs isZero])
		ifTrue: [^ self].
	[ Smalltalk tools timeProfiler spyOnProcess: selectedProcess forMilliseconds: secs * 1000 ] forkAt: selectedProcess priority + 1.
]

{ #category : #'stack list' }
SpecProcessBrowser >> moreStack [
	self updateStackList: 2000
]

{ #category : #'process actions' }
SpecProcessBrowser >> nameAndRulesFor: aProcess [ 
	"Answer a nickname and two flags: allow-stop, and allow-debug"
	aProcess == autoUpdateProcess ifTrue: [ ^{'my auto-update process'. true. true} ].
	^self class nameAndRulesFor: aProcess 

]

{ #category : #'process actions' }
SpecProcessBrowser >> nameAndRulesForSelectedProcess [
	"Answer a nickname and two flags: allow-stop, and allow-debug"
	^self nameAndRulesFor: selectedProcess
]

{ #category : #'process list' }
SpecProcessBrowser >> nextContext [
	| initialProcessIndex initialStackIndex found |
	searchString isEmpty ifTrue: [ ^false ].
	initialProcessIndex := self processListIndex.
	initialStackIndex := self stackListIndex.
	found := false.
	initialProcessIndex
		to: self processList size
		do: [:pi | found
				ifFalse: [self processListIndex: pi.
					self stackNameList
						withIndexDo: [:name :si | (found not
									and: [pi ~= initialProcessIndex
											or: [si > initialStackIndex]])
								ifTrue: [(name includesSubstring: searchString)
										ifTrue: [self stackListIndex: si.
											found := true]]]]].
	found
		ifFalse: [self processListIndex: initialProcessIndex.
			self stackListIndex: initialStackIndex].
	^ found
]

{ #category : #'process list' }
SpecProcessBrowser >> notify: errorString at: location in: aStream [ 
	"A syntax error happened when I was trying to highlight my pc. 
	Raise a signal so that it can be ignored."
	Warning signal: 'syntax error'
]

{ #category : #updating }
SpecProcessBrowser >> pauseAutoUpdate [
	self isAutoUpdating
		ifTrue: [ autoUpdateProcess suspend ].
	self updateProcessList
]

{ #category : #'stack list' }
SpecProcessBrowser >> pcRange [
	"Answer the indices in the source code for the method corresponding to  
	the selected context's program counter value."
	(selectedContext isNil or: [textPresenter isEmptyOrNil])
		ifTrue: [^ 1 to: 0].
	^selectedContext debuggerMap
		rangeForPC: (selectedContext pc ifNotNil: [:pc| pc] ifNil: [selectedContext method endPC])
		contextIsActiveContext: stackListIndex = 1
]

{ #category : #'process list' }
SpecProcessBrowser >> prettyNameForProcess: aProcess [ 
	| nameAndRules |
	aProcess ifNil: [ ^'<nil>' ].
	nameAndRules := self nameAndRulesFor: aProcess.
	^ aProcess browserPrintStringWith: nameAndRules first
]

{ #category : #accessing }
SpecProcessBrowser >> processLabel [
	^processLabel
]

{ #category : #accessing }
SpecProcessBrowser >> processList [
	^ processList
]

{ #category : #accessing }
SpecProcessBrowser >> processListIndex [
	^ processListIndex
]

{ #category : #accessing }
SpecProcessBrowser >> processListIndex: index [ 
	processListIndex := index.
	selectedProcess := processList
				at: index
				ifAbsent: [].
	self updateStackList.
	self changed: #processListIndex.
]

{ #category : #'process list' }
SpecProcessBrowser >> processListKey: aKey from: aView [ 
	self perform: (self keyEventsDict at: aKey ifAbsent: [ ^ self ])
]

{ #category : #menu }
SpecProcessBrowser >> processListMenu: aMenu shifted: shifted [
	selectedProcess ifNil: [ ^ nil ].
	aMenu addAllFromPragma: 'processBrowserProcessMenu' target: self.
	^ aMenu
]

{ #category : #accessing }
SpecProcessBrowser >> processListPresenter [
	^processListPresenter
]

{ #category : #'process list' }
SpecProcessBrowser >> processNameList [
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

{ #category : #views }
SpecProcessBrowser >> refactor [

	^ NautilusRefactoring model: self
]

{ #category : #shortcuts }
SpecProcessBrowser >> registerProcessListShortcuts: aWidget [
	aWidget
		bindKeyCombination: $i meta
		toAction: [ selectedProcess ifNotNil: [ self inspectProcess ] ].
	aWidget
		bindKeyCombination: $I meta
		toAction: [ selectedProcess ifNotNil: [ self exploreProcess ] ].
	aWidget
		bindKeyCombination: $P meta
		toAction: [ selectedProcess ifNotNil: [ self inspectPointers ] ].
	aWidget
		bindKeyCombination: $e meta
		toAction: [ selectedProcess ifNotNil: [ self explorePointers ] ].
	aWidget
		bindKeyCombination: $t meta
		toAction: [ selectedProcess ifNotNil: [ self terminateProcess ] ].
	aWidget
		bindKeyCombination: $r meta
		toAction: [ selectedProcess ifNotNil: [ self resumeProcess ] ].
	aWidget
		bindKeyCombination: $s meta
		toAction: [ selectedProcess ifNotNil: [ self suspendProcess ] ].
	aWidget
		bindKeyCombination: $p meta
		toAction: [ selectedProcess ifNotNil: [ self changePriority ] ].
	aWidget
		bindKeyCombination: $d meta
		toAction: [ selectedProcess ifNotNil: [ self debugProcess ] ].
	aWidget
		bindKeyCombination: $m meta
		toAction: [ selectedProcess ifNotNil: [ self messageTally ] ].
	aWidget
		bindKeyCombination: $S meta
		toAction: [ selectedProcess ifNotNil: [ self signalSemaphore ] ].
	aWidget
		bindKeyCombination: $k meta
		toAction: [ selectedProcess ifNotNil: [ self moreStack ] ].
	aWidget
		bindKeyCombination: $f meta
		toAction: [ selectedProcess ifNotNil: [ self findContext ] ].
	aWidget
		bindKeyCombination: $g meta
		toAction: [ selectedProcess ifNotNil: [ self nextContext ] ].
	"aWidget
		bindKeyCombination: $a meta
		toAction: [ selectedProcess ifNotNil: [ self toggleAutoUpdate ] ].
	aWidget
		bindKeyCombination: $u meta
		toAction: [ selectedProcess ifNotNil: [ self updateProcessList ] ]."
]

{ #category : #shortcuts }
SpecProcessBrowser >> registerStackListShortcuts: aWidget [
	aWidget
		bindKeyCombination: $c meta
		toAction: [ selectedContext ifNotNil: [ self inspectContext ] ].
	aWidget
		bindKeyCombination: $C meta
		toAction: [ selectedContext ifNotNil: [ self exploreContext ] ].
	aWidget
		bindKeyCombination: $i meta
		toAction: [ selectedContext ifNotNil: [ self inspectReceiver ] ].
	aWidget
		bindKeyCombination: $I meta
		toAction: [ selectedContext ifNotNil: [ self exploreReceiver ] ].
	aWidget
		bindKeyCombination: $b meta
		toAction: [ selectedContext ifNotNil: [ self browseContext ] ]
]

{ #category : #'process actions' }
SpecProcessBrowser >> resumeProcess [
	selectedProcess
		ifNil: [^ self].
	self class resumeProcess: selectedProcess.
	self updateProcessList
]

{ #category : #accessing }
SpecProcessBrowser >> selectedClass [
	"Answer the class in which the currently selected context's method was  found."
	^ selectedClass
		ifNil: [ selectedClass := selectedContext receiver
				ifNil: [ selectedSelector := selectedContext method selector.
					   selectedContext method methodClass ]
				ifNotNil: [ selectedContext methodClass ]]
]

{ #category : #accessing }
SpecProcessBrowser >> selectedClassOrMetaClass [
	^self doItReceiver class
]

{ #category : #accessing }
SpecProcessBrowser >> selectedContext [
	^selectedContext
]

{ #category : #accessing }
SpecProcessBrowser >> selectedMethod [
	^selectedContext ifNotNil: [ selectedContext method ]
]

{ #category : #accessing }
SpecProcessBrowser >> selectedProcess [
	^selectedProcess
]

{ #category : #accessing }
SpecProcessBrowser >> selectedSelector [
	"Answer the class in which the currently selected context's method was  
	found."
	^ selectedSelector
		ifNil: [selectedSelector := selectedContext receiver
				ifNil: [selectedClass := selectedContext method methodClass
					   selectedContext method selector]
				ifNotNil: [selectedContext selector]]
]

{ #category : #updating }
SpecProcessBrowser >> setUpdateCallbackAfter: seconds [
	deferredMessageRecipient
		ifNotNil: [ 
			| d |
			d := Delay forSeconds: seconds.
			[ d wait.
			d := nil. 
			deferredMessageRecipient defer: [ self updateProcessList ] ] fork ]
]

{ #category : #updating }
SpecProcessBrowser >> shoutAboutToStyle: aPluggableShoutMorphOrView [

	selectedContext ifNil: [^false].
	aPluggableShoutMorphOrView classOrMetaClass: self selectedClass.
	^ true

]

{ #category : #'process actions' }
SpecProcessBrowser >> signalSemaphore [
	(selectedProcess suspendingList isKindOf: Semaphore)
		ifFalse: [^ self].
	[selectedProcess suspendingList signal] fork.
	(Delay forMilliseconds: 300) wait.
	"Hate to make the UI wait, but it's convenient..."
	self updateProcessList
]

{ #category : #accessing }
SpecProcessBrowser >> stackLabel [
	^stackLabel
]

{ #category : #accessing }
SpecProcessBrowser >> stackList [
	^ stackList
		ifNil: [#()]
]

{ #category : #accessing }
SpecProcessBrowser >> stackListIndex [
	^ stackListIndex
]

{ #category : #accessing }
SpecProcessBrowser >> stackListIndex: index [ 
	stackListIndex := index.
	selectedContext := (stackList notNil
						and: [index > 0]) ifTrue:
							[stackList at: index ifAbsent: []].
	selectedClass := nil.
	selectedSelector := nil.
]

{ #category : #views }
SpecProcessBrowser >> stackListKey: aKey from: aView [ 
	aKey = $c ifTrue: [ self inspectContext].
	aKey = $C ifTrue: [ self exploreContext].
	aKey = $i ifTrue: [ self inspectReceiver].
	aKey = $I ifTrue: [ self exploreReceiver].
	aKey = $b ifTrue: [ self browseContext].


]

{ #category : #menu }
SpecProcessBrowser >> stackListMenu: aMenu shifted: shifted [
	selectedContext ifNil: [ ^ nil ].
	aMenu addAllFromPragma: 'processBrowserStackMenu' target: self.
	^ aMenu
]

{ #category : #accessing }
SpecProcessBrowser >> stackListPresenter [
	^stackListPresenter
]

{ #category : #'stack list' }
SpecProcessBrowser >> stackNameList [
	^ stackList
		ifNil: [#()]
		ifNotNil: [stackList collect: [:each | each asString]]
]

{ #category : #updating }
SpecProcessBrowser >> startAutoUpdate [
	self isAutoUpdatingPaused ifTrue: [ ^autoUpdateProcess resume ].
	self isAutoUpdating
		ifFalse: [| delay | 
			delay := Delay forSeconds: 2.
			autoUpdateProcess := [[self hasView]
						whileTrue: [delay wait.
							deferredMessageRecipient ifNotNil: [
								deferredMessageRecipient defer: [self updateProcessList]]
							ifNil: [ self updateProcessList ]].
					autoUpdateProcess := nil] fork].
	self updateProcessList
]

{ #category : #initialization }
SpecProcessBrowser >> startCPUWatcher [
	"Answers whether I started the CPUWatcher"
	CPUWatcher isMonitoring
		ifFalse: [ 
					CPUWatcher startMonitoringPeriod: 5 rate: 100 threshold: 0.85.
					self setUpdateCallbackAfter: 7.
					^ true ]
]

{ #category : #updating }
SpecProcessBrowser >> stopAutoUpdate [
	autoUpdateProcess ifNotNil: [
		autoUpdateProcess terminate.
		autoUpdateProcess := nil].
	self updateProcessList
]

{ #category : #initialization }
SpecProcessBrowser >> stopCPUWatcher [

	CPUWatcher stopMonitoring.
	self updateProcessList.
	startedCPUWatcher := false	"so a manual restart won't be killed later" 
]

{ #category : #'process actions' }
SpecProcessBrowser >> suspendProcess [
	| nameAndRules |
	selectedProcess isSuspended
		ifTrue: [^ self].
	nameAndRules := self nameAndRulesForSelectedProcess.
	nameAndRules second
		ifFalse: [self inform: 'Nope, won''t suspend ' , nameAndRules first.
			^ self].
	self class suspendProcess: selectedProcess.
	self updateProcessList
]

{ #category : #'process actions' }
SpecProcessBrowser >> terminateProcess [
	| nameAndRules |
	nameAndRules := self nameAndRulesForSelectedProcess.
	nameAndRules second
		ifFalse: [self inform: 'Nope, won''t kill ' , nameAndRules first.
			^ self].
	self class terminateProcess: selectedProcess.	
	self updateProcessList.
]

{ #category : #accessing }
SpecProcessBrowser >> textPresenter [
	^textPresenter

]

{ #category : #accessing }
SpecProcessBrowser >> theCPUWatcherButton [
	^ theCPUWatcherButton
]

{ #category : #api }
SpecProcessBrowser >> title [ 
	^ 'Process Browser'
]

{ #category : #updating }
SpecProcessBrowser >> toggleAutoUpdate [
	self isAutoUpdating
		ifTrue: [ self stopAutoUpdate ]
		ifFalse: [ self startAutoUpdate ].

]

{ #category : #accessing }
SpecProcessBrowser >> updateButton [
	^ updateButton
]

{ #category : #'process list' }
SpecProcessBrowser >> updateProcessList [
	| oldSelectedProcess newIndex now |
	now := Time millisecondClockValue.
	now - lastUpdate < 500
		ifTrue: [ ^ self ].
	"Don't update too fast"
	lastUpdate := now.
	oldSelectedProcess := selectedProcess.
	processList := selectedProcess := selectedSelector := nil.
	Smalltalk garbageCollectMost.
	"lose defunct processes"
	processList := Process allSubInstances
		reject: [ :each | each isTerminated ].
	processList := processList sort: [ :a :b | a priority >= b priority ].
	processList := WeakArray withAll: processList.
	newIndex := processList indexOf: oldSelectedProcess ifAbsent: [ 0 ].
	self processListIndex: newIndex.
	self updateView
]

{ #category : #'stack list' }
SpecProcessBrowser >> updateStackList [
	self updateStackList: 20
]

{ #category : #'stack list' }
SpecProcessBrowser >> updateStackList: depth [ 
	| suspendedContext oldHighlight |
	selectedProcess
		ifNil: [^ self changeStackListTo: nil].
	(stackList notNil and: [ stackListIndex > 0 ])
		ifTrue: [oldHighlight := stackList at: stackListIndex].
	selectedProcess == Processor activeProcess
		ifTrue: [self
				changeStackListTo: (thisContext stackOfSize: depth)]
		ifFalse: [suspendedContext := selectedProcess suspendedContext.
			suspendedContext
				ifNil: [self changeStackListTo: nil]
				ifNotNil: [self
						changeStackListTo: (suspendedContext stackOfSize: depth)]].
	self
		stackListIndex: (stackList
				ifNil: [0]
				ifNotNil: [stackList indexOf: oldHighlight]).
]

{ #category : #updating }
SpecProcessBrowser >> updateView [
	processListPresenter
		items: self processNameList;
		setSelectedIndex: processListIndex.
		
	stackList
		ifNotNil: [ stackListPresenter
				items: self stackList;
				setSelectedIndex: stackListIndex;
				displayBlock: #asString ];
		ifNil: [ stackListPresenter
				items: #();
				displayBlock: #asString ].
			
	selectedContext
		ifNotNil: [ textPresenter
				text: selectedContext sourceCode;
				behavior: selectedContext methodClass ];
		ifNil: [ textPresenter
				text: ''.
				stackListPresenter resetSelection ]
]

{ #category : #'process actions' }
SpecProcessBrowser >> wasProcessSuspendedByProcessBrowser: aProcess [
	^self class suspendedProcesses includesKey: aProcess
]

{ #category : #initialization }
SpecProcessBrowser >> windowIsClosing [
	startedCPUWatcher ifTrue: [ CPUWatcher stopMonitoring ]
]
