codex conversation [unknown] present Image Playground on prayer start page

Resolve the first imported office as the background source while the prayer is
still on its start page, allowing the automatic Image Playground task to run and
an accepted image to appear there. Skip the removed programmatic creator on iOS
27, stop silently rejecting presentation based on the environment support flag,
and expose an Utwórz tło retry button whenever the selected prayer lacks an
image. Add regression coverage for start-page office resolution. The complete
importer suite passes all 24 tests on the physical iPhone 15 Pro. The normal app
build succeeded and was installed on that device. A console launch reached the
home screen, but no backgroundless prayer was selected during the observation,
so actual system-sheet presentation still requires interactive confirmation.
User review then found that the prefilled description remained too abstract,
using phrases such as Catholic sacred art, prayer themes, and Liturgy of the
Hours instead of specifying a physical place and visible objects. This revision
does not correct that prompt-quality defect.
