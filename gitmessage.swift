bound prayer history growth

Keep at most the newest 512 prayer sessions and compact oversized legacy history
as soon as it loads. Add a regression test proving the ceiling keeps the newest
records. The measured 130-session history is only 11.3 KB after compression, but
this prevents it from growing without limit.
