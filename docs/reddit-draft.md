# Reddit announcement draft

Not posted. Intended for r/Remarkable, in the owner's voice.

Before publishing: the repository is currently private and has no public
release. Decide whether to make it public, select a license, review the source
for publication, replace the link placeholder below, and check the community's
current rules/flair. Do not announce public availability until those steps are
actually complete. The owner's October 1 recording confirms refresh/import/Open;
chosen-folder and v0.3.0 live-search physical checks remain separate.

## Video attachment

Attach [wikipedia-reddit-demo.mp4](media/wikipedia-reddit-demo.mp4) to the post
(19.8 seconds, portrait H.264 MP4, no audio). This is an edited extract of the
owner's real device recording: results → refresh existing article → PDF ready
→ Open PDF → native reader. Initial false start and some waiting removed;
screen-sharing footer cropped, original playback speed retained. No synthetic UI.

Suggested caption: “From a Wikipedia result to a PDF in the normal reMarkable
reader. Here I'm refreshing an article I'd already downloaded. Waiting trimmed.”

The clip is v0.2.2 footage: it shows the older Download again button, not the
new Refresh article text link or search-as-you-type. Do not present it as a
demo of incremental search. Reproduce the cut with
`bash scripts/make-reddit-demo.sh /path/to/the-original-recording.mov`.

## Title

Wikipedia on the reMarkable without turning it into a browser

## Post

I don't think e-readers need to become browsers. As much as possible, I want to
stay in reading mode: open a document, read it, highlight things, write in the
margins. Use the device for what it's good at.

But sometimes what's missing is just the link between something you want to
read and getting it onto the device. You shouldn't need to pick up your phone
or laptop, find the article, make a PDF and send it over every time.

That's the idea behind this little Wikipedia app. Not browsing Wikipedia on
the reMarkable, but getting a Wikipedia article into the reader.

You open it from AppLoad, search for an article, and tap the PDF button. It adds
the article to My files, or a folder you choose. Once it's saved, tap Open PDF
and you're back in the normal reader, reading and annotating it like any other
document. That's basically it.

Results now update as you type, without the keyboard disappearing. Open PDF is
the main action once the download is ready. There's also a small Refresh article
link if you want to fetch another copy later; it leaves the old PDF and its
annotations alone. The clip was recorded just before those UI refinements, so
you'll see the older refresh button there.

It talks directly to Wikipedia. No account, API key or server of mine in the
middle. You do need Wi-Fi to search and download; once the PDF is there, you
can read it offline. English and Hebrew are supported for now.

I've been using it on my Paper Pro on 3.29.0.148 with AppLoad 0.6.0, and the
search → PDF → native reader flow works. I haven't qualified it on the Move yet,
so I'm not claiming support there just because the layout fits.

Installation instructions and source: **[public repository / installation link]**

You'll need developer mode, SSH, and an existing XOVI/AppLoad setup. Build the
app, run the guarded installer for the supported Paper Pro firmware, refresh
AppLoad, and open Wikipedia. The README has the commands. It doesn't install
XOVI for you, patch the editor or restart the tablet.

A couple of caveats: PDF generation depends on Wikipedia's service, and the
downloaded PDF follows your normal reMarkable cloud-sync settings. This isn't
a way to keep documents out of the cloud.

I'd like more of these small connections to things we want to read, while
keeping the actual reading in the device's own reader. Curious if others see
it that way too, and what else you'd want to get onto yours this easily.
