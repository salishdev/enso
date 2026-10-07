//
//  EnsoTests.swift
//  EnsoTests
//
//  Created by aman on 09/06/26.
//

import Testing
@testable import Enso

/// New-tab folder inheritance (#28): ⌘N and the palette default follow the
/// active tab into its folder; loose tabs keep making top-level tabs.
@MainActor
struct NewTabFolderInheritanceTests {

    private func makeStore() -> (
        store: TerminalSessionStore,
        folder: TerminalFolder,
        folderTab: TerminalSession,
        looseTab: TerminalSession
    ) {
        let folderTab = TerminalSession(title: "main", workingDirectory: "/tmp/project")
        let folder = TerminalFolder(title: "enso", sessions: [folderTab])
        let looseTab = TerminalSession(title: "scratch", workingDirectory: "/tmp/scratch")
        let store = TerminalSessionStore(
            spaces: [
                SidebarSpace(
                    name: "Main",
                    pinnedFolders: [folder],
                    ephemeralSessions: [looseTab]
                )
            ],
            persistToDisk: false
        )
        return (store, folder, folderTab, looseTab)
    }

    @Test func newTabJoinsActiveTabsFolder() async throws {
        let (store, folder, folderTab, _) = makeStore()
        store.selection = folderTab.id

        store.createSessionInheritingWorkingDirectory()

        let updated = try #require(store.activeSpace.pinnedFolders.first { $0.id == folder.id })
        #expect(updated.sessions.count == 2)
        let created = try #require(updated.sessions.last)
        #expect(created.id == store.selection)
        #expect(created.workingDirectory == "/tmp/project")
        #expect(store.activeSpace.ephemeralSessions.count == 1)
    }

    @Test func newTabStaysTopLevelForLooseTab() async throws {
        let (store, folder, _, looseTab) = makeStore()
        store.selection = looseTab.id

        store.createSessionInheritingWorkingDirectory()

        let updated = try #require(store.activeSpace.pinnedFolders.first { $0.id == folder.id })
        #expect(updated.sessions.count == 1)
        #expect(store.activeSpace.ephemeralSessions.count == 2)
        let created = try #require(store.activeSpace.ephemeralSessions.last)
        #expect(created.id == store.selection)
        #expect(created.workingDirectory == "/tmp/scratch")
    }

    @Test func selectionFolderReflectsActiveTab() async throws {
        let (store, folder, folderTab, looseTab) = makeStore()

        store.selection = folderTab.id
        #expect(store.selectionFolder?.id == folder.id)

        store.selection = looseTab.id
        #expect(store.selectionFolder == nil)
    }

    @Test func explicitWorkingDirectoryOverridesFolderInheritance() async throws {
        let (store, folder, _, looseTab) = makeStore()
        store.selection = looseTab.id

        store.createSession(inFolder: folder.id, workingDirectory: "/tmp/elsewhere")

        let updated = try #require(store.activeSpace.pinnedFolders.first { $0.id == folder.id })
        let created = try #require(updated.sessions.last)
        #expect(created.workingDirectory == "/tmp/elsewhere")

        // Without an explicit directory the folder's most recently active
        // tab still decides, as before.
        store.createSession(inFolder: folder.id)
        let again = try #require(store.activeSpace.pinnedFolders.first { $0.id == folder.id })
        #expect(again.sessions.last?.workingDirectory == "/tmp/elsewhere")
    }

    /// A tab with nothing to inherit leaves its cwd to Ghostty's
    /// `working-directory` config instead of forcing home.
    @Test func tabWithoutDirectoryDefersToGhosttyConfig() async throws {
        let (store, _, _, _) = makeStore()

        store.createSession()

        let created = try #require(store.selectedSession)
        #expect(created.workingDirectoryPending)
        #expect(created.inheritableWorkingDirectory == nil)

        // A tab opened from it before the shell reports must defer too,
        // not pin itself to the home stand-in.
        store.createSessionInheritingWorkingDirectory()
        #expect(store.selectedSession?.id != created.id)
        #expect(store.selectedSession?.workingDirectoryPending == true)
    }

    /// The shell's first report resolves the stand-in — even when Ghostty
    /// started it in home, which matches the stand-in exactly.
    @Test func firstShellReportResolvesPendingDirectory() async throws {
        let (store, _, _, _) = makeStore()
        store.createSession()
        let created = try #require(store.selectedSession)

        store.updateWorkingDirectory(created.id, to: created.workingDirectory)

        #expect(store.selectedSession?.workingDirectoryPending == false)
        #expect(store.selectedSession?.inheritableWorkingDirectory == created.workingDirectory)
    }
}
