# Reddit announcement draft

Not posted. Intended for r/Remarkable, in the owner's voice.

Before publishing: the repository is currently private and has no public
release. Decide whether to make it public, select a license, review the source
for publication, replace the link placeholder below, and check the community's
current rules/flair. Do not announce public availability until those steps are
actually complete. Also finish the on-device v0.1.1 keyboard recheck.

## Title

I made a small app to search Wikipedia and download articles as PDFs on the reMarkable

## Post

I wanted to look something up on Wikipedia and read it on my reMarkable without
having to get my phone or computer involved. So I made a small app for it.

You open it from AppLoad, search for an article, and tap the PDF button. It adds
the article to My files, where you can read it and annotate it like any other
PDF. That's basically it.

It talks directly to Wikipedia. No account, API key or server of mine in the
middle. You do need Wi-Fi to search and download; once the PDF is there, you
can read it offline. English and Hebrew are supported for now.

One detail I cared about: the results stay there while you're editing the
query. Search or Enter runs the next search, so things don't keep disappearing
while you're trying to pick an article.

I've been using it on my Paper Pro on 3.29.0.148 with AppLoad 0.6.0, and the
search → PDF → My files flow works. I haven't qualified it on the Move yet,
so I'm not claiming support there just because the layout fits.

Installation instructions and source: **[public repository / installation link]**

You'll need developer mode, SSH, and an existing XOVI/AppLoad setup. Build the
app, run the guarded installer for the supported Paper Pro firmware, refresh
AppLoad, and open Wikipedia. The README has the commands. It doesn't install
XOVI for you, patch the editor or restart the tablet.

A couple of caveats: PDF generation depends on Wikipedia's service, and the
downloaded PDF follows your normal reMarkable cloud-sync settings. This isn't
a way to keep documents out of the cloud.

Curious if others would find this useful, and what you'd want to improve.
