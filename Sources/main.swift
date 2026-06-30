import AppKit
import Security
import ServiceManagement

// MARK: - Constants

let supabaseURL = "https://db.torbox.app"
let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJlanhmeXRrbm5rb2VndHRldXpzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjkxMjgzMzAsImV4cCI6MjA0NDcwNDMzMH0.vIQWcZuN6Nx3DnkmsWLK25J8BM3TTA_8Tb4GoK99MqM"
let keychainService = "com.torbox.cdn-menu"

struct CDNOption {
    let name: String
    let value: String
    let flag: String
}

let cdnOptions: [CDNOption] = [
    CDNOption(name: "Auto", value: "auto", flag: "⚡️"),
    CDNOption(name: "Cloudflare (ERTH)", value: "erth", flag: "🌐"),
    CDNOption(name: "BunnyCDN (HARE)", value: "hare", flag: "🌐"),
    CDNOption(name: "US West (WNAM)", value: "wnam", flag: "🇺🇸"),
    CDNOption(name: "US East (ENAM)", value: "enam", flag: "🇺🇸"),
    CDNOption(name: "US Central (CNAM)", value: "cnam", flag: "🇺🇸"),
    CDNOption(name: "US South (SNAM)", value: "snam", flag: "🇺🇸"),
    CDNOption(name: "Latin America (LATM)", value: "latm", flag: "🇧🇷"),
    CDNOption(name: "West Europe (WEUR)", value: "weur", flag: "🇳🇱"),
    CDNOption(name: "Central Europe (CEUR)", value: "ceur", flag: "🇫🇷"),
    CDNOption(name: "North Europe (NEUR)", value: "neur", flag: "🇬🇧"),
    CDNOption(name: "South Europe (SEUR)", value: "seur", flag: "🇵🇹"),
    CDNOption(name: "Norway (NORD)", value: "nord", flag: "🇳🇴"),
    CDNOption(name: "Ukraine (SLAV)", value: "slav", flag: "🇺🇦"),
    CDNOption(name: "Asia Pacific (APAC)", value: "apac", flag: "🇸🇬"),
    CDNOption(name: "South Oceania (SOCE)", value: "soce", flag: "🇦🇺"),
    CDNOption(name: "India (INDI)", value: "indi", flag: "🇮🇳"),
    CDNOption(name: "Japan (JAPN)", value: "japn", flag: "🇯🇵"),
    CDNOption(name: "Middle East (MEAS)", value: "meas", flag: "🇮🇱"),
    CDNOption(name: "South Africa (ZAFR)", value: "zafr", flag: "🇿🇦"),
]

// MARK: - Keychain

func keychainSave(account: String, password: String) {
    let data = password.data(using: .utf8)!
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecAttrAccount as String: account,
    ]
    SecItemDelete(query as CFDictionary)
    var add = query
    add[kSecValueData as String] = data
    SecItemAdd(add as CFDictionary, nil)
}

func keychainLoad() -> (email: String, password: String)? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecReturnAttributes as String: true,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
          let dict = item as? [String: Any],
          let account = dict[kSecAttrAccount as String] as? String,
          let data = dict[kSecValueData as String] as? Data,
          let password = String(data: data, encoding: .utf8)
    else { return nil }
    return (account, password)
}

func keychainDelete() {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
    ]
    SecItemDelete(query as CFDictionary)
}

// MARK: - API

struct AuthSession {
    let accessToken: String
    let userId: String
}

func authenticate(email: String, password: String) async throws -> AuthSession {
    let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=password")!
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
    req.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
    let body: [String: Any] = ["email": email, "password": password, "gotrue_meta_security": ["captcha_token": ""]]
    req.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (data, response) = try await URLSession.shared.data(for: req)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        throw NSError(domain: "auth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Login failed"])
    }
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    let token = json["access_token"] as! String
    let user = json["user"] as! [String: Any]
    let userId = user["id"] as! String
    return AuthSession(accessToken: token, userId: userId)
}

func fetchCurrentCDN(session: AuthSession) async throws -> String {
    let url = URL(string: "\(supabaseURL)/rest/v1/settings?select=cdn_selection&auth_id=eq.\(session.userId)")!
    var req = URLRequest(url: url)
    req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
    req.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
    req.setValue("application/vnd.pgrst.object+json", forHTTPHeaderField: "Accept")
    req.setValue("public", forHTTPHeaderField: "Accept-Profile")
    let (data, _) = try await URLSession.shared.data(for: req)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    return json["cdn_selection"] as? String ?? "auto"
}

func setCDN(session: AuthSession, value: String) async throws {
    let url = URL(string: "\(supabaseURL)/rest/v1/settings?on_conflict=auth_id")!
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
    req.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("public", forHTTPHeaderField: "Content-Profile")
    req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
    let body: [String: Any] = ["auth_id": session.userId, "cdn_selection": value]
    req.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (_, response) = try await URLSession.shared.data(for: req)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 || http.statusCode == 201 else {
        throw NSError(domain: "api", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to update CDN"])
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var session: AuthSession?
    var currentCDN = "auto"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Enable paste in text fields
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu
        let mainMenu = NSMenu()
        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🌐"
        
        Task { await autoLogin() }
    }

    func autoLogin() async {
        guard let creds = keychainLoad() else {
            await MainActor.run { buildMenu() }
            return
        }
        do {
            session = try await authenticate(email: creds.email, password: creds.password)
            currentCDN = try await fetchCurrentCDN(session: session!)
            await MainActor.run { buildMenu() }
        } catch {
            await MainActor.run { buildMenu() }
        }
    }

    func buildMenu() {
        let menu = NSMenu()

        if session == nil {
            menu.addItem(withTitle: "Not logged in", action: nil, keyEquivalent: "")
            menu.addItem(NSMenuItem.separator())
            let login = NSMenuItem(title: "Login...", action: #selector(promptLogin), keyEquivalent: "l")
            login.target = self
            menu.addItem(login)
        } else {
            let currentOption = cdnOptions.first(where: { $0.value == currentCDN }) ?? cdnOptions[0]
            menu.addItem(withTitle: "Current: \(currentOption.flag) \(currentOption.name)", action: nil, keyEquivalent: "")
            menu.addItem(NSMenuItem.separator())

            for option in cdnOptions {
                let item = NSMenuItem(title: "\(option.flag) \(option.name)", action: #selector(selectCDN(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = option.value
                if option.value == currentCDN {
                    item.state = .on
                }
                menu.addItem(item)
            }

            menu.addItem(NSMenuItem.separator())
            let refresh = NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r")
            refresh.target = self
            menu.addItem(refresh)
            let logout = NSMenuItem(title: "Logout", action: #selector(logout), keyEquivalent: "")
            logout.target = self
            menu.addItem(logout)
        }

        menu.addItem(NSMenuItem.separator())
        let launchAtLogin = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchAtLogin.target = self
        launchAtLogin.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(launchAtLogin)
        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc func promptLogin() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "TorBox Login"
        alert.informativeText = "Enter your TorBox email and password"
        alert.addButton(withTitle: "Login")
        alert.addButton(withTitle: "Cancel")

        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 280, height: 56))
        stack.orientation = .vertical
        stack.spacing = 8

        let emailField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        emailField.placeholderString = "Email"
        let passField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        passField.placeholderString = "Password"

        stack.addArrangedSubview(emailField)
        stack.addArrangedSubview(passField)
        alert.accessoryView = stack

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let email = emailField.stringValue
        let password = passField.stringValue
        guard !email.isEmpty, !password.isEmpty else { return }

        Task {
            do {
                self.session = try await authenticate(email: email, password: password)
                keychainSave(account: email, password: password)
                self.currentCDN = try await fetchCurrentCDN(session: self.session!)
                await MainActor.run { self.buildMenu() }
            } catch {
                await MainActor.run {
                    let a = NSAlert()
                    a.messageText = "Login Failed"
                    a.informativeText = error.localizedDescription
                    a.runModal()
                }
            }
        }
    }

    @objc func selectCDN(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        Task {
            do {
                try await ensureSession()
                try await setCDN(session: session!, value: value)
                self.currentCDN = value
                await MainActor.run { self.buildMenu() }
            } catch {
                await MainActor.run {
                    let a = NSAlert()
                    a.messageText = "Error"
                    a.informativeText = error.localizedDescription
                    a.runModal()
                }
            }
        }
    }

    func ensureSession() async throws {
        if let creds = keychainLoad() {
            session = try await authenticate(email: creds.email, password: creds.password)
        } else {
            throw NSError(domain: "auth", code: 3, userInfo: [NSLocalizedDescriptionKey: "Not logged in"])
        }
    }

    @objc func refresh() {
        Task { await autoLogin() }
    }

    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let a = NSAlert()
            a.messageText = "Error"
            a.informativeText = error.localizedDescription
            a.runModal()
        }
        buildMenu()
    }

    @objc func logout() {
        keychainDelete()
        session = nil
        currentCDN = "auto"
        buildMenu()
    }
}

// MARK: - Main

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
