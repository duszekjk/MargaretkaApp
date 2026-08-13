restore verified server photo variants instead of locally recompressing them

Remove unsafe local recompression controls and maintenance. Ordinary sync only
fills missing previews. Add the explicit “Pobierz ponownie zdjęcia” action,
which replaces existing device-specific copies only after image decoding is
verified. Raise app and widget build number to 75.
