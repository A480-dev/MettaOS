#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    let args: Vec<String> = std::env::args().collect();

    if args.iter().any(|a| a == "--daemon") {
        // Plasma/KDE native notifications handle desktop alerts; keep process alive if invoked as service
        loop {
            std::thread::sleep(std::time::Duration::from_secs(3600));
        }
    }

    if args.iter().any(|a| a == "--send") {
        let title = args.get(args.iter().position(|a| a == "--send").unwrap_or(0) + 1)
            .cloned()
            .unwrap_or_else(|| "METTA OS".into());
        let body = args.get(args.iter().position(|a| a == "--send").unwrap_or(0) + 2)
            .cloned()
            .unwrap_or_default();
        let _ = std::process::Command::new("notify-send")
            .arg(&title)
            .arg(&body)
            .status();
        return;
    }

    metta_notify_lib::run()
}
