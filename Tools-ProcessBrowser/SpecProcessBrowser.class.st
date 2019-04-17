"
SpecProcessBrowser new openWithSpec
"
Class {
	#name : #SpecProcessBrowser,
	#superclass : #ComposablePresenter,
	#instVars : [
		'selectedClass',
		'selectedSelector',
		'searchString',
		'autoUpdateProcess',
		'deferredMessageRecipient',
		'startedCPUWatcher',
		'processListPresenter',
		'stackListPresenter',
		'textPresenter',
		'autoUpdateButton',
		'updateButton',
		'theCPUWatcherButton'
	],
	#classVars : [
		'SuspendedProcesses',
		'WellKnownProcesses'
	],
	#category : #'Tools-ProcessBrowser-Core'
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
	^ SpecPanedLayout newVertical
		add:
			(SpecPanedLayout newHorizontal
				add:
					(SpecBoxLayout newVertical
						add: '(Priority) Process List'
							withConstraints: [ :constraints | constraints height: self defaultFont height ];
						add: #processListPresenter;
						yourself);
				add:
					(SpecBoxLayout newVertical
						add: 'Stack List'
							withConstraints: [ :constraints | constraints height: self defaultFont height ];
						add: #stackListPresenter));
		add:
			(SpecBoxLayout newVertical
				add:
					(SpecBoxLayout newHorizontal
						add: #autoUpdateButton;
						add: #updateButton;
						add: #theCPUWatcherButton)
					withConstraints: [ :constraints | constraints height: self toolbarHeight ];
				add: #textPresenter);
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

{ #category : #'process control' }
SpecProcessBrowser class >> nameAndRulesFor: aProcess [
	"Answer a nickname and two flags: allow-stop, and allow-debug"

	| rules |
	rules := {nil . true . true}.
	WellKnownProcesses
		do: [ :blockAndRules | 
			blockAndRules key value == aProcess
				ifTrue: [ rules := blockAndRules value value ] ].
	rules first
		ifNil: [ rules at: 1 put: aProcess suspendedContext asString ].
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
	aProcess
		ifNotNil: [ self suspendedProcesses removeKey: aProcess ifAbsent: [  ].
			aProcess terminate ]
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

{ #category : #accessing }
SpecProcessBrowser >> autoUpdateButton [
	^ autoUpdateButton
]

{ #category : #'stack list' }
SpecProcessBrowser >> browseContext [
	self selectedContext ifNil: [ ^ self ].
	Smalltalk tools browser
		openOnClass: self selectedClass
		selector: self selectedSelector
]

{ #category : #'process actions' }
SpecProcessBrowser >> changePriority [
	| str newPriority nameAndRules |
	nameAndRules := self nameAndRulesForSelectedProcess.
	nameAndRules third
		ifFalse:
			[ self inform: 'Nope, won''t change priority of ' , nameAndRules first.
			^ self ].
	str := UIManager default
		request: 'New priority'
		initialAnswer: self selectedProcess priority asString.
	str isEmptyOrNil
		ifTrue: [ ^ self ].
	newPriority := str asNumber asInteger.
	(newPriority < 1 or: [ newPriority > Processor highestPriority ])
		ifTrue: [ self inform: 'Bad priority'.
			^ self ].
	self class setProcess: self selectedProcess toPriority: newPriority.
	self updateProcessList
]

{ #category : #'process actions' }
SpecProcessBrowser >> debugProcess [
	| nameAndRules |
	nameAndRules := self nameAndRulesForSelectedProcess.
	nameAndRules third
		ifFalse: [self inform: 'Nope, won''t debug ' , nameAndRules first.
			^ self].
	self class debugProcess: self selectedProcess.
]

{ #category : #accessing }
SpecProcessBrowser >> deferredMessageRecipient: anObject [
	deferredMessageRecipient := anObject
]

{ #category : #shortcuts }
SpecProcessBrowser >> ensureKeyBindingsFor: aWidget [
	super ensureKeyBindingsFor: aWidget.
	self registerProcessListShortcuts: processListPresenter.
	self registerStackListShortcuts: stackListPresenter
]

{ #category : #'process actions' }
SpecProcessBrowser >> explorePointers [
	(Smalltalk tools hasToolNamed: #pointerExplorer)
		ifTrue: [ Smalltalk tools pointerExplorer openOn: self selectedProcess ]
		ifFalse: [ self inspectPointers ]
]

{ #category : #'process list' }
SpecProcessBrowser >> findContext [
	| initialProcessIndex initialStackIndex found |
	initialProcessIndex := processListPresenter selection selectedIndex.
	initialStackIndex := stackListPresenter selection selectedIndex.
	searchString := UIManager default
		request: 'Enter a string to search for in the process stack lists'
		initialAnswer: searchString.
	searchString isEmptyOrNil
		ifTrue: [ ^ false ].
	processListPresenter selectIndex: 1.
	stackListPresenter selectIndex: 1.
	found := self nextContext.
	found
		ifFalse: [ processListPresenter selectIndex: initialProcessIndex.
			stackListPresenter selectIndex: initialStackIndex ].
	^ found
]

{ #category : #'cpu watcher' }
SpecProcessBrowser >> getCPUWatcherState [
	Smalltalk globals
		at: #CPUWatcher
		ifPresent: [ :pw | 
			^(pw isMonitoring)]
]

{ #category : #view }
SpecProcessBrowser >> hasView [
	^self dependents isEmptyOrNil not
]

{ #category : #initialization }
SpecProcessBrowser >> initialize [
	super initialize.
	self class registerWellKnownProcesses.
	startedCPUWatcher := CPUWatcher cpuWatcherEnabled
		and: [ self startCPUWatcher ].
	self updateProcessList
]

{ #category : #initialization }
SpecProcessBrowser >> initializePresenter [
	processListPresenter
		whenSelectionChangedDo: [ :selection | self updateStackList ].
	stackListPresenter
		whenSelectionChangedDo: [ :selection | self updateTextArea ].
	autoUpdateButton action: [ self toggleAutoUpdate ].
	updateButton action: [ self updateProcessList ].
	theCPUWatcherButton action: [ self toggleCPUWatcher ]
]

{ #category : #initialization }
SpecProcessBrowser >> initializeWidgets [
	processListPresenter := self newList contextMenu: self processMenu.
	stackListPresenter := self newList contextMenu: self stackMenu..
	textPresenter := self newCode.
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
	processListPresenter
		displayBlock: [ :process | self prettyNameForProcess: process ];
		sortingBlock: #priority descending.
	stackListPresenter displayBlock: #asString.
	self focusOrder
		add: processListPresenter;
		add: stackListPresenter;
		add: textPresenter.
	self deferredMessageRecipient: WorldState
]

{ #category : #initialization }
SpecProcessBrowser >> initializeWindow: aWindowPresenter [
	| fontWidth rowHeight |
	fontWidth := StandardFonts defaultFont widthOfString: 'M'.
	rowHeight := self class inputTextHeight.
	aWindowPresenter initialExtent: 90 @ 20 * (fontWidth @ rowHeight).
	aWindowPresenter title: self title
]

{ #category : #'stack list' }
SpecProcessBrowser >> inspectContext [
	self selectedContext inspect
]

{ #category : #'process actions' }
SpecProcessBrowser >> inspectPointers [
	(self selectedProcess pointersToExcept: {self processList . thisContext . self})
		ifNotEmpty: [ :pointers | pointers inspectWithLabel: 'Objects pointing to ' , self selectedProcess browserPrintString ]
]

{ #category : #'process list' }
SpecProcessBrowser >> inspectProcess [
	self selectedProcess inspect
]

{ #category : #'stack list' }
SpecProcessBrowser >> inspectReceiver [
	self selectedContext
		ifNotNil: [ self selectedContext receiver inspect ]
]

{ #category : #'auto update' }
SpecProcessBrowser >> isAutoUpdating [
	^ autoUpdateProcess notNil and: [ autoUpdateProcess isSuspended not ]
]

{ #category : #'auto update' }
SpecProcessBrowser >> isAutoUpdatingPaused [
	^autoUpdateProcess notNil and: [ autoUpdateProcess isSuspended ]
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
	[ Smalltalk tools timeProfiler spyOnProcess: self selectedProcess forMilliseconds: secs * 1000 ] forkAt: self selectedProcess priority + 1.
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

	^ self nameAndRulesFor: self selectedProcess
]

{ #category : #'process list' }
SpecProcessBrowser >> nextContext [
	| initialProcessIndex initialStackIndex found |
	searchString isEmptyOrNil
		ifTrue: [ ^ false ].
	initialProcessIndex := processListPresenter selection selectedIndex.
	initialStackIndex := stackListPresenter selection selectedIndex.
	found := false.
	initialProcessIndex to: self processList size do: [ :pi | 
		found
			ifFalse: [ processListPresenter selectIndex: pi.
				self stackList
					withIndexDo: [ :name :si | 
						(found not
							and: [ pi ~= initialProcessIndex or: [ si > initialStackIndex ] ])
							ifTrue: [ (name asString includesSubstring: searchString)
									ifTrue: [ stackListPresenter selectIndex: si.
										found := true ] ] ] ] ].
	found
		ifFalse: [ processListPresenter selectIndex: initialProcessIndex.
			stackListPresenter selectIndex: initialStackIndex ].
	^ found
]

{ #category : #'process list' }
SpecProcessBrowser >> notify: errorString at: location in: aStream [
	"A syntax error happened when I was trying to highlight my pc. 
	Raise a signal so that it can be ignored."
	self flag: #remove.

	Warning signal: 'syntax error'
]

{ #category : #'process list' }
SpecProcessBrowser >> prettyNameForProcess: aProcess [
	| tally percent processName |
	tally := CPUWatcher current ifNotNil: #tally.

	percent := tally ifNotNil: [ (((tally occurrencesOf: aProcess) * 100.0 / tally size roundTo: 1) asString padLeftTo: 2) , '% ' ] ifNil: [ '' ].

	processName := aProcess ifNil: [ '<nil>' ] ifNotNil: [ aProcess browserPrintStringWith: (self nameAndRulesFor: aProcess) first ].

	^ percent , processName
]

{ #category : #accessing }
SpecProcessBrowser >> processList [
	^ self processListPresenter items
]

{ #category : #accessing }
SpecProcessBrowser >> processListPresenter [
	^processListPresenter
]

{ #category : #menu }
SpecProcessBrowser >> processMenu [
	^ self newMenu
		addGroup: [ :aGroup | 
			aGroup
				addItem: [ :anItem | 
					anItem
						name: 'Inspect';
						shortcut: $i meta;
						action: [ self inspectProcess ] ];
				addItem: [ :anItem | 
					anItem
						name: 'Inspect Pointers';
						shortcut: $P meta;
						action: [ self inspectPointers ] ];
				addItem: [ :anItem | 
					anItem
						name: 'Explore Pointers';
						shortcut: $e meta;
						visibleIf: [ Smalltalk globals includesKey: #PointerExplorer ];
						action: [ self explorePointers ] ];
				addItem: [ :anItem | 
					anItem
						name: 'Terminate';
						shortcut: $t meta;
						visibleIf: [ self nameAndRulesForSelectedProcess second ];
						action: [ self terminateProcess ] ];
				addItem: [ :anItem | 
					anItem
						name: 'Resume';
						shortcut: $r meta;
						visibleIf: [ self nameAndRulesForSelectedProcess second and: [ self selectedProcess isSuspended ] ];
						action: [ self resumeProcess ] ];
				addItem: [ :anItem | 
					anItem
						name: 'Suspend';
						shortcut: $s meta;
						visibleIf: [ self nameAndRulesForSelectedProcess second and: [ self selectedProcess isSuspended not ] ];
						action: [ self suspendProcess ] ];
				addItem: [ :anItem | 
					anItem
						name: 'Change Priority';
						shortcut: $p meta;
						visibleIf: [ self nameAndRulesForSelectedProcess third ];
						action: [ self changePriority ] ];
				addItem: [ :anItem | 
					anItem
						name: 'Debug';
						shortcut: $d meta;
						visibleIf: [ self nameAndRulesForSelectedProcess third ];
						action: [ self debugProcess ] ];
				addItem: [ :anItem | 
					anItem
						name: 'Profile Messages';
						shortcut: $m meta;
						action: [ self messageTally ] ];
				addItem: [ :anItem | 
					anItem
						name: 'Signal Semaphore';
						shortcut: $S meta;
						visibleIf: [ self selectedProcess suspendingList isKindOf: Semaphore ];
						action: [ self signalSemaphore ] ];
				addItem: [ :anItem | 
					anItem
						name: 'Full Stack';
						shortcut: $k meta;
						action: [ self moreStack ] ] ];
		addGroup: [ :group | 
			group
				addItem: [ :anItem | 
					anItem
						name: 'Find Context';
						shortcut: $f meta;
						action: [ self findContext ] ];
				addItem: [ :anItem | 
					anItem
						name: 'Find Again';
						shortcut: $g meta;
						action: [ self nextContext ] ] ]
]

{ #category : #'process list' }
SpecProcessBrowser >> processNameList [
	^ (self processList asOrderedCollection copyWithout: nil) collect: [ :each | self prettyNameForProcess: each ]
]

{ #category : #view }
SpecProcessBrowser >> refactor [
	self flag: #remove.
	^ NautilusRefactoring model: self
]

{ #category : #shortcuts }
SpecProcessBrowser >> registerProcessListShortcuts: aWidget [
	aWidget bindKeyCombination: $i meta toAction: [ self inspectProcess ].
	aWidget bindKeyCombination: $P meta toAction: [ self inspectPointers ].
	aWidget bindKeyCombination: $e meta toAction: [ self explorePointers ].
	aWidget bindKeyCombination: $t meta toAction: [ self terminateProcess ].
	aWidget bindKeyCombination: $r meta toAction: [ self resumeProcess ].
	aWidget bindKeyCombination: $s meta toAction: [ self suspendProcess ].
	aWidget bindKeyCombination: $p meta toAction: [ self changePriority ].
	aWidget bindKeyCombination: $d meta toAction: [ self debugProcess ].
	aWidget bindKeyCombination: $m meta toAction: [ self messageTally ].
	aWidget bindKeyCombination: $S meta toAction: [ self signalSemaphore ].
	aWidget bindKeyCombination: $k meta toAction: [ self moreStack ].
	aWidget bindKeyCombination: $f meta toAction: [ self findContext ].
	aWidget bindKeyCombination: $g meta toAction: [ self nextContext ]
]

{ #category : #shortcuts }
SpecProcessBrowser >> registerStackListShortcuts: aWidget [
	aWidget
		bindKeyCombination: $c meta
		toAction: [ self selectedContext
				ifNotNil: [ self inspectContext ] ].
	aWidget
		bindKeyCombination: $I meta
		toAction: [ self selectedContext
				ifNotNil: [ self inspectReceiver ] ].
	aWidget
		bindKeyCombination: $b meta
		toAction: [ self selectedContext
				ifNotNil: [ self browseContext ] ]
]

{ #category : #'process actions' }
SpecProcessBrowser >> resumeProcess [
	self class resumeProcess: self selectedProcess.
	self updateProcessList
]

{ #category : #accessing }
SpecProcessBrowser >> selectedClass [
	"Answer the class in which the currently selected context's method was  found."

	^ selectedClass
		ifNil: [ selectedClass := self selectedContext receiver
				ifNil: [ selectedSelector := self selectedContext method selector.
					self selectedContext method methodClass ]
				ifNotNil: [ self selectedContext methodClass ] ]
]

{ #category : #accessing }
SpecProcessBrowser >> selectedContext [

	^ self stackListPresenter selection selectedItem
]

{ #category : #accessing }
SpecProcessBrowser >> selectedMethod [
	^ self selectedContext
		ifNotNil: [ self selectedContext method ]
]

{ #category : #accessing }
SpecProcessBrowser >> selectedProcess [
	^ self processListPresenter selection selectedItem
]

{ #category : #accessing }
SpecProcessBrowser >> selectedSelector [
	"Answer the class in which the currently selected context's method was  
	found."
	^ selectedSelector
		ifNil: [ selectedSelector := self selectedContext receiver
				ifNil: [ selectedClass := self selectedContext method methodClass
						selectedContext method selector ]
				ifNotNil: [ self selectedContext selector ] ]
]

{ #category : #'cpu watcher' }
SpecProcessBrowser >> setUpdateCallbackAfter: seconds [
	deferredMessageRecipient
		ifNotNil: [ 
			| d |
			d := Delay forSeconds: seconds.
			[ d wait.
			d := nil. 
			deferredMessageRecipient defer: [ self updateProcessList ] ] fork ]
]

{ #category : #view }
SpecProcessBrowser >> shoutAboutToStyle: aPluggableShoutMorphOrView [
	self flag: #remove.
	self selectedContext ifNil: [ ^ false ].
	aPluggableShoutMorphOrView classOrMetaClass: self selectedClass.
	^ true
]

{ #category : #'process actions' }
SpecProcessBrowser >> signalSemaphore [
	(self selectedProcess suspendingList isKindOf: Semaphore) ifFalse: [ ^ self ].
	
	[ self selectedProcess suspendingList signal ] fork.
	(Delay forMilliseconds: 300) wait.
	"Hate to make the UI wait, but it's convenient..."
	self updateProcessList
]

{ #category : #accessing }
SpecProcessBrowser >> stackListPresenter [
	^stackListPresenter
]

{ #category : #menu }
SpecProcessBrowser >> stackMenu [
	^ self newMenu
		addItem: [ :anItem | 
			anItem
				name: 'Inspect Context';
				shortcut: $c meta;
				action: [ self inspectContext ] ];
		addItem: [ :anItem | 
			anItem
				name: 'Inspect Receiver';
				shortcut: $I meta;
				action: [ self inspectReceiver ] ];
		addItem: [ :anItem | 
			anItem
				name: 'Browse';
				shortcut: $b meta;
				action: [ self browseContext ] ]
]

{ #category : #'auto update' }
SpecProcessBrowser >> startAutoUpdate [
	self isAutoUpdatingPaused
		ifTrue: [ ^ autoUpdateProcess resume ].
	self isAutoUpdating
		ifFalse: [ | delay |
			delay := Delay forSeconds: 2.
			autoUpdateProcess := [ [ 
			self hasView ]
				whileTrue: [ delay wait.
					deferredMessageRecipient
						ifNotNil: [ deferredMessageRecipient defer: [ self updateProcessList ] ]
						ifNil: [ self updateProcessList ] ].
			autoUpdateProcess := nil ] fork ].
	self updateProcessList
]

{ #category : #'cpu watcher' }
SpecProcessBrowser >> startCPUWatcher [
	"Answers whether I started the CPUWatcher"
	CPUWatcher isMonitoring
		ifFalse: [ 
					self inform: 'Start CPU Watcher after 7 seconds.'.
					CPUWatcher startMonitoringPeriod: 5 rate: 100 threshold: 0.85.
					self setUpdateCallbackAfter: 7.
					^ true ]
]

{ #category : #'auto update' }
SpecProcessBrowser >> stopAutoUpdate [
	autoUpdateProcess ifNotNil: [
		autoUpdateProcess terminate.
		autoUpdateProcess := nil].
	self updateProcessList
]

{ #category : #'cpu watcher' }
SpecProcessBrowser >> stopCPUWatcher [

	CPUWatcher stopMonitoring.
	self updateProcessList.
	startedCPUWatcher := false	"so a manual restart won't be killed later" 
]

{ #category : #'process actions' }
SpecProcessBrowser >> suspendProcess [
	| nameAndRules |
	self selectedProcess isSuspended ifTrue: [^ self].
	
	nameAndRules := self nameAndRulesForSelectedProcess.
	nameAndRules second
		ifFalse: [self inform: 'Nope, won''t suspend ' , nameAndRules first.
			^ self].
	self class suspendProcess: self selectedProcess.
	self updateProcessList
]

{ #category : #'process actions' }
SpecProcessBrowser >> terminateProcess [
	| nameAndRules |
	nameAndRules := self nameAndRulesForSelectedProcess.
	nameAndRules first = 'my auto-update process'
		ifTrue:
			[ self toggleAutoUpdate.
			^ self ] .nameAndRules second
		ifFalse: [ self inform: 'Nope, won''t kill ' , nameAndRules first.
			^ self ].
	self class terminateProcess: self selectedProcess.
	self updateProcessList
]

{ #category : #accessing }
SpecProcessBrowser >> text [
	self flag: #remove.
	^ self selectedContext sourceCode
]

{ #category : #accessing }
SpecProcessBrowser >> textPresenter [
	^textPresenter

]

{ #category : #accessing }
SpecProcessBrowser >> theCPUWatcherButton [
	^ theCPUWatcherButton
]

{ #category : #'api-window' }
SpecProcessBrowser >> title [ 
	^ 'Process Browser'
]

{ #category : #'auto update' }
SpecProcessBrowser >> toggleAutoUpdate [

	self isAutoUpdating
		ifTrue: [ self stopAutoUpdate.
			autoUpdateButton
				label: 'Start auto-update';
				icon: (self iconNamed: #smallDoIt) ]
		ifFalse: [ self startAutoUpdate.
			autoUpdateButton
				label: 'Stop auto-update';
				icon: (self iconNamed: #stop) ]
]

{ #category : #'cpu watcher' }
SpecProcessBrowser >> toggleCPUWatcher [
	self getCPUWatcherState
		ifTrue: [ theCPUWatcherButton
				label: 'Start CPUWatcher';
				icon: (self iconNamed: #smallDoIt).
			self stopCPUWatcher ]
		ifFalse: [ theCPUWatcherButton
				label: 'Stop CPUWatcher';
				icon: (self iconNamed: #stop).
			self startCPUWatcher ]
]

{ #category : #accessing }
SpecProcessBrowser >> updateButton [
	^ updateButton
]

{ #category : #'process list' }
SpecProcessBrowser >> updateProcessList [
	| processList selectedProcess |
	selectedProcess := self selectedProcess.
	selectedSelector := nil.
	Smalltalk garbageCollectMost.
	"lose defunct processes"
	processList := WeakArray
		withAll: (Process allSubInstances reject: [ :each | each isTerminated ]).
	processListPresenter
		items: processList;
		selectItem: selectedProcess.
	self updateStackList
]

{ #category : #'stack list' }
SpecProcessBrowser >> updateStackList [
	self updateStackList: 20
]

{ #category : #'stack list' }
SpecProcessBrowser >> updateStackList: depth [
	| stackList suspendedContext selectedContext |
	self selectedProcess
		ifNotNil: [ selectedContext := self selectedContext.
			self selectedProcess == Processor activeProcess
				ifTrue: [ stackList := thisContext stackOfSize: depth ]
				ifFalse: [ suspendedContext := self selectedProcess suspendedContext.
					suspendedContext
						ifNil: [ stackList := nil ]
						ifNotNil: [ stackList := suspendedContext stackOfSize: depth ] ].
			selectedClass := nil.
			selectedSelector := nil ].
	stackListPresenter
		items: (stackList ifNil:[#()]);
		selectItem: selectedContext
]

{ #category : #'stack list' }
SpecProcessBrowser >> updateTextArea [
	self selectedContext 
		ifNotNil: [ textPresenter
				text: self selectedContext sourceCode;
				behavior: self selectedContext methodClass ];
		ifNil: [ textPresenter text: '' ]
]

{ #category : #'api-window' }
SpecProcessBrowser >> windowIsClosing [
	startedCPUWatcher
		ifTrue: [ CPUWatcher stopMonitoring ].
	self isAutoUpdating
		ifTrue: [ self stopAutoUpdate ]
]
