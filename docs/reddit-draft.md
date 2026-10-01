# Reddit announcement

Destination: r/RemarkableTablet, flair **Self-Promotion**. Owner approved posting
and public MIT source on October 2, 2026. GitHub is now public under MIT.
Reddit text and flair are saved in the owner's account, but **not posted**:
native video upload is blocked by the Chrome extension's file-URL permission.
The owner has been asked to enable that permission. Resume the existing draft
rather than creating a duplicate; attach video before publishing.

## Media

Attach [wikipedia-reddit-demo.mp4](media/wikipedia-reddit-demo.mp4) as native
video, not merely a Markdown link. The README uses the matching
[looping GIF](media/wikipedia-demo.gif). Source: owner's October 2 00.28.06
recording, v0.3.2. Live search → download/import → Open PDF → native reader and
highlighting. Waits trimmed; typing/selection at 1.25x; unrelated screen-share
footer cropped only after keyboard closes. Original is unchanged. No synthetic
UI. The reader has unrelated add-ons, not bundled with Wikipedia.

Reproduce: `bash scripts/make-reddit-demo.sh /path/to/recording.mov`.

## Title

Wikipedia on the reMarkable without turning it into a browser

## Post

I don't think e-readers need to become browsers. As much as possible, I want to stay in reading mode: open a document, read it, highlight things, write in the margins. Use the device for what it's good at.

But sometimes we're missing the link between something we want to read and getting it onto the device. You shouldn't need to pick up your phone or laptop, find the article, make a PDF and send it over every time.

So I made a little Wikipedia app for reMarkable. Open it from AppLoad, start typing, pick an article and tap PDF. It saves to My files or a folder you choose. Then tap Open PDF and you're in the normal reader. That's basically it.

It uses the native keyboard, with results updating as you type. There's also a small Refresh article link to fetch a new copy later, without touching the old PDF or its annotations.

It talks directly to Wikipedia. No account, API key or server of mine in the middle. Wi-Fi for searching/downloading, then offline reading. English and Hebrew Wikipedia for now.

Source and installation instructions (MIT): https://github.com/guibor/remarkable-wiki#installation-from-source

This is a developer-mode app: you'll need SSH and an existing XOVI/AppLoad setup. The README has the build/install commands. I've tested it on Paper Pro 3.29.0.148 with AppLoad 0.6.0; Move isn't qualified yet. The installer checks the model/firmware and doesn't patch the editor or restart the tablet. PDFs follow your normal cloud-sync settings.

The clip is trimmed, with typing/selection slightly sped up. The extra reader-toolbar mods you see aren't part of this app.

I'd like more of these small connections to things we want to read, while keeping the actual reading in the device's own reader.
