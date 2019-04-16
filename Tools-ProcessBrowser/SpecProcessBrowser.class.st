"
SpecProcessBrowser new openWithSpec
"
Class {
	#name : #SpecProcessBrowser,
	#superclass : #ComposablePresenter,
	#instVars : [
		'processList',
		'stackList',
		'selectedProcess',
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

{ #category : #menu }
SpecProcessBrowser class >> menuProcessList: aBuilder [
	<contextMenu>
	<processBrowserProcessMenu>
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
		withSeparatorAfter

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
	stackListPresenter selection selectedItem 
 ifNil: [ ^ self ]. 
	Smalltalk tools browser openOnClass: self selectedClass selector: self selectedSelector
]

{ #category : #view }
SpecProcessBrowser >> browsedEnvironment [
	self flag: #remove.
	^ Smalltalk globals
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
		initialAnswer: selectedProcess priority asString.
	str isEmptyOrNil
		ifTrue: [ ^ self ].
	newPriority := str asNumber asInteger.
	(newPriority < 1 or: [ newPriority > Processor highestPriority ])
		ifTrue: [ self inform: 'Bad priority'.
			^ self ].
	self class setProcess: selectedProcess toPriority: newPriority.
	self updateProcessList
]

{ #category : #'process list' }
SpecProcessBrowser >> changeProcessListSelection: item [
	selectedProcess := processList
		at: processListPresenter selection selectedIndex.
	self updateStackList.
	item
		ifNotNil: [ stackListPresenter
				items: self stackList;
				displayBlock: #asString.
			textPresenter text: ''.
			stackListPresenter unselectAll ];
		ifNil: [ stackListPresenter items: #().
			textPresenter text: '' ].
	processListPresenter contextMenu: self processMenu
]

{ #category : #'stack list' }
SpecProcessBrowser >> changeStackListSelection: item [
	item
		ifNotNil: [ textPresenter
				text: stackListPresenter selection selectedItem sourceCode;
				behavior: stackListPresenter selection selectedItem methodClass ];
		ifNil: [ textPresenter text: '' ].
	stackListPresenter contextMenu: self stackMenu
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
	self flag: #remove.
	^ stackListPresenter selection selectedItem
]

{ #category : #accessing }
SpecProcessBrowser >> doItReceiver [
	self flag: #remove.
	^ stackListPresenter selection selectedItem
		ifNil: [ selectedProcess ]
		ifNotNil: [ stackListPresenter selection selectedItem receiver ]
]

{ #category : #shortcuts }
SpecProcessBrowser >> ensureKeyBindingsFor: aWidget [
	super ensureKeyBindingsFor: aWidget.
	self registerProcessListShortcuts: processListPresenter.
	self registerStackListShortcuts: stackListPresenter
]

{ #category : #'stack list' }
SpecProcessBrowser >> exploreContext [
	stackListPresenter selection selectedItem inspect
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
	stackListPresenter selection selectedItem ifNotNil: [ stackListPresenter selection selectedItem receiver inspect ]
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
		whenSelectionChangedDo:
			[ :selection | self changeProcessListSelection: selection selectedItem ].
	stackListPresenter
		whenSelectionChangedDo: [ :selection | 
			self changeStackListSelection: selection selectedItem ].
	autoUpdateButton action: [ self toggleAutoUpdate ].
	updateButton action: [ self updateProcessList ].
	theCPUWatcherButton action: [ self toggleCPUWatcher ]
]

{ #category : #initialization }
SpecProcessBrowser >> initializeWidgets [
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
	stackListPresenter selection selectedItem inspect
]

{ #category : #'process actions' }
SpecProcessBrowser >> inspectPointers [
	| tc pointers |
		selectedProcess ifNil: [ ^ self ].
	tc := thisContext.
	pointers := selectedProcess
		pointersToExcept:
			{self processList.
			tc.
			self}.
	pointers ifEmpty: [ ^ self ].
	pointers
		inspectWithLabel: 'Objects pointing to ' , selectedProcess browserPrintString
]

{ #category : #'process list' }
SpecProcessBrowser >> inspectProcess [
	selectedProcess inspect
]

{ #category : #'stack list' }
SpecProcessBrowser >> inspectReceiver [
	stackListPresenter selection selectedItem ifNotNil: [ stackListPresenter selection selectedItem receiver inspect ]
]

{ #category : #'update process' }
SpecProcessBrowser >> isAutoUpdating [
	^ autoUpdateProcess notNil and: [ autoUpdateProcess isSuspended not ]
]

{ #category : #'update process' }
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
	| nameAndRules |
	aProcess ifNil: [ ^'<nil>' ].
	nameAndRules := self nameAndRulesFor: aProcess.
	^ aProcess browserPrintStringWith: nameAndRules first
]

{ #category : #accessing }
SpecProcessBrowser >> processList [
	^ processList
]

{ #category : #accessing }
SpecProcessBrowser >> processListPresenter [
	^processListPresenter
]

{ #category : #menu }
SpecProcessBrowser >> processMenu [
	^self newMenu
				addAllFromPragma: 'processBrowserProcessMenu'
				target: self.
]

{ #category : #'process list' }
SpecProcessBrowser >> processNameList [
	"since processList is a WeakArray, we have to strengthen the result"
	| tally |
	tally := CPUWatcher
		ifNotNil: [ CPUWatcher current ifNotNil: [ CPUWatcher current tally ] ].
	^ (processList asOrderedCollection copyWithout: nil)
		collect: [ :each | 
			| percent |
			percent := tally
				ifNotNil: [ (((tally occurrencesOf: each) * 100.0 / tally size roundTo: 1)
						asString padLeftTo: 2) , '% ' ]
				ifNil: [ '' ].
			percent , (self prettyNameForProcess: each) ]
]

{ #category : #view }
SpecProcessBrowser >> refactor [
	self flag: #remove.
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
		toAction: [ selectedProcess ifNotNil: [ self nextContext ] ]
]

{ #category : #shortcuts }
SpecProcessBrowser >> registerStackListShortcuts: aWidget [
	aWidget
		bindKeyCombination: $c meta
		toAction: [ stackListPresenter selection selectedItem ifNotNil: [ self inspectContext ] ].
	aWidget
		bindKeyCombination: $C meta
		toAction: [ stackListPresenter selection selectedItem  ifNotNil: [ self exploreContext ] ].
	aWidget
		bindKeyCombination: $i meta
		toAction: [ stackListPresenter selection selectedItem  ifNotNil: [ self inspectReceiver ] ].
	aWidget
		bindKeyCombination: $I meta
		toAction: [ stackListPresenter selection selectedItem  ifNotNil: [ self exploreReceiver ] ].
	aWidget
		bindKeyCombination: $b meta
		toAction: [ stackListPresenter selection selectedItem  ifNotNil: [ self browseContext ] ]
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
		ifNil: [ selectedClass := stackListPresenter selection selectedItem  receiver
				ifNil: [ selectedSelector := stackListPresenter selection selectedItem  method selector.
					stackListPresenter selection selectedItem  method methodClass ]
				ifNotNil: [ stackListPresenter selection selectedItem  methodClass ] ]
]

{ #category : #accessing }
SpecProcessBrowser >> selectedClassOrMetaClass [
	self flag: #remove.
	^ self doItReceiver class
]

{ #category : #accessing }
SpecProcessBrowser >> selectedContext [
	^ stackListPresenter selection selectedItem 
]

{ #category : #accessing }
SpecProcessBrowser >> selectedMethod [
	^ stackListPresenter selection selectedItem  ifNotNil: [ stackListPresenter selection selectedItem  method ]
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
		ifNil: [ selectedSelector := stackListPresenter selection selectedItem  receiver
				ifNil: [ selectedClass := stackListPresenter selection selectedItem  method methodClass selectedContext
						method selector ]
				ifNotNil: [ stackListPresenter selection selectedItem  selector ] ]
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
	stackListPresenter selection selectedItem  ifNil: [ ^ false ].
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
SpecProcessBrowser >> stackList [
	^ stackList
		ifNil: [#()]
]

{ #category : #accessing }
SpecProcessBrowser >> stackListPresenter [
	^stackListPresenter
]

{ #category : #menu }
SpecProcessBrowser >> stackMenu [
	^self newMenu
		addAllFromPragma: 'processBrowserStackMenu'
		target: self.
]

{ #category : #'update process' }
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

{ #category : #'update process' }
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
	nameAndRules first = 'my auto-update process'
		ifTrue:
			[ self toggleAutoUpdate.
			^ self ] .nameAndRules second
		ifFalse: [ self inform: 'Nope, won''t kill ' , nameAndRules first.
			^ self ].
	self class terminateProcess: selectedProcess.
	self updateProcessList
]

{ #category : #accessing }
SpecProcessBrowser >> text [
	self flag: #remove.
	^ stackListPresenter selection selectedItem sourceCode
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

{ #category : #'update process' }
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
	| oldSelectedProcess newIndex |
	oldSelectedProcess := selectedProcess.
	processList := selectedProcess := selectedSelector := nil.
	Smalltalk garbageCollectMost.
	"lose defunct processes"
	processList := Process allSubInstances
		reject: [ :each | each isTerminated ].
	processList := processList sort: [ :a :b | a priority >= b priority ].
	processList := WeakArray withAll: processList.
	newIndex := processList indexOf: oldSelectedProcess ifAbsent: [ 1 ].
	self updateProcessListPresenter: newIndex.
	self updateStackList
]

{ #category : #'update presenter' }
SpecProcessBrowser >> updateProcessListPresenter: index [
	selectedProcess := processList at: index.
	processListPresenter
		items: self processNameList;
		selectIndex: index
]

{ #category : #'stack list' }
SpecProcessBrowser >> updateStackList [
	self updateStackList: 20
]

{ #category : #'stack list' }
SpecProcessBrowser >> updateStackList: depth [
	| suspendedContext oldHighlight index |
	processListPresenter selection selectedItem
		ifNil: [ stackList := nil.
			^ self ].
	stackList
		ifNotNil: [ oldHighlight := stackListPresenter selection selectedItem ].
	selectedProcess == Processor activeProcess
		ifTrue: [ stackList := thisContext stackOfSize: depth ]
		ifFalse: [ suspendedContext := selectedProcess suspendedContext.
			suspendedContext
				ifNil: [ stackList := nil ]
				ifNotNil: [stackList:= (suspendedContext stackOfSize: depth) ] ].
	index := stackList
		ifNil: [ 0 ]
		ifNotNil: [ stackList indexOf: oldHighlight ].
	selectedClass := nil.
	selectedSelector := nil.
	self updateStackListPresenter: index
]

{ #category : #'update presenter' }
SpecProcessBrowser >> updateStackListPresenter: index [
	stackList
		ifNotNil: [ stackListPresenter
				items: self stackList;
				selectIndex: index;
				displayBlock: #asString ]
]

{ #category : #'api-window' }
SpecProcessBrowser >> windowIsClosing [
	startedCPUWatcher
		ifTrue: [ CPUWatcher stopMonitoring ].
	self isAutoUpdating
		ifTrue: [ self stopAutoUpdate ]
]
