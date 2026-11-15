import UIKit
import WebKit

final class BrowserViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UITextFieldDelegate {

    private var webView: WKWebView!
    private let urlField = UITextField()
    private let shieldButton = UIButton(type: .system)
    private let menuButton = UIButton(type: .system)
    private let progress = UIProgressView(progressViewStyle: .bar)
    private let statusLabel = UILabel()

    private var progressObs: NSKeyValueObservation?
    private var urlObs: NSKeyValueObservation?
    private var protectionOn = true
    private var firstLoadDone = false

    private let home = URL(string: "https://m.youtube.com")!
    private let barColor = UIColor(red: 28/255, green: 32/255, blue: 38/255, alpha: 1)
    private let green = UIColor(red: 127/255, green: 216/255, blue: 142/255, alpha: 1)

    // MARK: Start

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = barColor

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptCanOpenWindowsAutomatically = false   // keine Popups
        config.websiteDataStore = .default()
        addScripts(to: config.userContentController)

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = .black
        webView.isOpaque = false

        buildLayout()

        progressObs = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
            guard let self = self else { return }
            self.progress.setProgress(Float(wv.estimatedProgress), animated: true)
            self.progress.isHidden = wv.estimatedProgress >= 1
        }
        // YouTube wechselt Seiten ohne neu zu laden -> Adresse trotzdem nachführen
        urlObs = webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
            guard let self = self, !self.urlField.isEditing else { return }
            self.urlField.text = wv.url?.absoluteString
        }

        updateShield()
        statusLabel.text = "🛡 Schutz wird vorbereitet …\n(beim ersten Start bis zu einer Minute)"
        statusLabel.isHidden = false

        Blocker.shared.prepare { [weak self] list in
            guard let self = self else { return }
            if let list = list { self.webView.configuration.userContentController.add(list) }
            self.statusLabel.isHidden = true
            self.updateShield()
            if !self.firstLoadDone {
                self.firstLoadDone = true
                self.webView.load(URLRequest(url: self.home))
            }
            if Blocker.shared.needsUpdate { self.updateList(silent: true) }
        }
    }

    // MARK: Skripte (Werbeflächen ausblenden, YouTube-Werbung überspringen)

    private func jsString(_ s: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [s]),
              var str = String(data: data, encoding: .utf8) else { return "\"\"" }
        str.removeFirst()   // [
        str.removeLast()    // ]
        return str
    }

    private func addScripts(to ucc: WKUserContentController) {
        if let url = Bundle.main.url(forResource: "cosmetic", withExtension: "css"),
           let css = try? String(contentsOf: url, encoding: .utf8) {
            let js = """
            (function(){
              if (document.getElementById('schildwall-css')) return;
              var s = document.createElement('style');
              s.id = 'schildwall-css';
              s.textContent = \(jsString(css));
              (document.head || document.documentElement).appendChild(s);
            })();
            """
            ucc.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        }
        if let url = Bundle.main.url(forResource: "youtube", withExtension: "js"),
           let yt = try? String(contentsOf: url, encoding: .utf8) {
            let js = """
            if (location.hostname === 'youtube.com' || location.hostname.endsWith('.youtube.com')) {
            \(yt)
            }
            """
            ucc.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
    }

    // MARK: Oberfläche

    private func makeButton(_ title: String, _ action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 20)
        b.tintColor = .white
        b.addTarget(self, action: action, for: .touchUpInside)
        b.setContentHuggingPriority(.required, for: .horizontal)
        b.setContentCompressionResistancePriority(.required, for: .horizontal)
        return b
    }

    private func buildLayout() {
        let back = makeButton("◀", #selector(goBack))
        let reload = makeButton("⟳", #selector(reloadPage))
        let homeB = makeButton("▶", #selector(goHome))

        menuButton.setTitle("☰", for: .normal)
        menuButton.titleLabel?.font = .systemFont(ofSize: 20)
        menuButton.tintColor = .white
        menuButton.addTarget(self, action: #selector(showMenu), for: .touchUpInside)
        menuButton.setContentHuggingPriority(.required, for: .horizontal)

        shieldButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        shieldButton.addTarget(self, action: #selector(showInfo), for: .touchUpInside)
        shieldButton.setContentHuggingPriority(.required, for: .horizontal)
        shieldButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        urlField.textColor = .white
        urlField.font = .systemFont(ofSize: 14)
        urlField.attributedPlaceholder = NSAttributedString(
            string: "Adresse oder Suche",
            attributes: [.foregroundColor: UIColor.gray])
        urlField.keyboardType = .webSearch
        urlField.returnKeyType = .go
        urlField.autocapitalizationType = .none
        urlField.autocorrectionType = .no
        urlField.clearButtonMode = .whileEditing
        urlField.delegate = self

        let bar = UIStackView(arrangedSubviews: [back, reload, urlField, homeB, menuButton, shieldButton])
        bar.axis = .horizontal
        bar.spacing = 10
        bar.alignment = .center

        progress.progressTintColor = green
        progress.trackTintColor = .clear

        statusLabel.textColor = green
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.font = .systemFont(ofSize: 15)

        for v in [bar, progress, webView!, statusLabel] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }

        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: g.topAnchor, constant: 4),
            bar.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 10),
            bar.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -10),
            bar.heightAnchor.constraint(equalToConstant: 40),

            progress.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 2),
            progress.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progress.heightAnchor.constraint(equalToConstant: 3),

            webView.topAnchor.constraint(equalTo: progress.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20)
        ])
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private func updateShield() {
        if protectionOn {
            shieldButton.setTitle("🛡", for: .normal)
            shieldButton.tintColor = green
        } else {
            shieldButton.setTitle("🛡 AUS", for: .normal)
            shieldButton.tintColor = .systemRed
        }
    }

    private func toast(_ text: String) {
        let a = UIAlertController(title: nil, message: text, preferredStyle: .alert)
        present(a, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { a.dismiss(animated: true) }
    }

    // MARK: Knöpfe

    @objc private func goBack() { if webView.canGoBack { webView.goBack() } }
    @objc private func reloadPage() { webView.reload() }
    @objc private func goHome() { webView.load(URLRequest(url: home)) }

    @objc private func showInfo() {
        let text = protectionOn
            ? "Schutz aktiv\n\(Blocker.shared.domainCount) Werbe- und Tracking-Domains gesperrt\nDrittanbieter-Cookies werden blockiert"
            : "Schutz ist AUS"
        let a = UIAlertController(title: "🛡 Schildwall", message: text, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    @objc private func showMenu() {
        let sheet = UIAlertController(title: "🛡 Schildwall", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: protectionOn ? "Schutz ausschalten" : "Schutz einschalten",
                                      style: .default) { [weak self] _ in self?.toggleProtection() })
        sheet.addAction(UIAlertAction(title: "⇩ Blockliste aktualisieren", style: .default) { [weak self] _ in
            self?.updateList(silent: false)
        })
        sheet.addAction(UIAlertAction(title: "🍪 Cookies & Website-Daten löschen", style: .destructive) { [weak self] _ in
            self?.clearData()
        })
        sheet.addAction(UIAlertAction(title: "Abbrechen", style: .cancel))
        sheet.popoverPresentationController?.sourceView = menuButton
        present(sheet, animated: true)
    }

    private func toggleProtection() {
        let ucc = webView.configuration.userContentController
        protectionOn.toggle()
        if protectionOn {
            if let list = Blocker.shared.ruleList { ucc.add(list) }
            addScripts(to: ucc)
        } else {
            ucc.removeAllContentRuleLists()
            ucc.removeAllUserScripts()
        }
        updateShield()
        webView.reload()
    }

    private func updateList(silent: Bool) {
        if !silent { toast("Lade neue Blockliste …") }
        Blocker.shared.downloadList { [weak self] ok in
            guard let self = self else { return }
            if !ok {
                if !silent { self.toast("Update fehlgeschlagen (Internet?)") }
                return
            }
            Blocker.shared.prepare { list in
                let ucc = self.webView.configuration.userContentController
                ucc.removeAllContentRuleLists()
                if self.protectionOn, let list = list { ucc.add(list) }
                if !silent { self.toast("Liste aktualisiert: \(Blocker.shared.domainCount) Domains") }
            }
        }
    }

    private func clearData() {
        let store = WKWebsiteDataStore.default()
        store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { [weak self] in
            self?.toast("Cookies und Website-Daten gelöscht 🍪")
            self?.webView.reload()
        }
    }

    // MARK: Adresszeile

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let t = (textField.text ?? "").trimmingCharacters(in: .whitespaces)
        textField.resignFirstResponder()
        guard !t.isEmpty else { return true }
        var url: URL?
        if t.hasPrefix("http://") || t.hasPrefix("https://") {
            url = URL(string: t)
        } else if t.contains("."), !t.contains(" ") {
            url = URL(string: "https://" + t)
        }
        if url == nil {
            let q = t.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? t
            url = URL(string: "https://duckduckgo.com/?q=" + q)
        }
        if let url = url { webView.load(URLRequest(url: url)) }
        return true
    }

    // MARK: WebView

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else {
            decisionHandler(.allow); return
        }
        if ["http", "https", "about", "blob", "data"].contains(scheme) {
            decisionHandler(.allow); return
        }
        // App-Store-Links o.ä. nur bei echtem Antippen öffnen (Werbung leitet gern ungefragt weiter)
        if navigationAction.navigationType == .linkActivated {
            UIApplication.shared.open(url)
        }
        decisionHandler(.cancel)
    }

    // Links mit target="_blank" im gleichen Fenster öffnen statt Popup
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, navigationAction.navigationType == .linkActivated {
            webView.load(navigationAction.request)
        }
        return nil
    }
}
