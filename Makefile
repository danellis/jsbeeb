FONTS=fonts/ttext-grc-ldh.png fonts/ttext-grc-udh.png fonts/ttext-grc.png fonts/ttext-grs-ldh.png fonts/ttext-grs-udh.png fonts/ttext-grs.png fonts/ttext-std-ldh.png fonts/ttext-std-udh.png fonts/ttext-std.png

all:: cpu.js os12.rom.js basic2.rom.js watforddfs144.rom.js $(FONTS)

fonts/%.png: fonts/%.bdf
	tools/mkfontbitmap.py $< $@

%.rom.js: roms/%.rom
	tools/convert_rom.py $< $@ $(@:.rom.js=_rom)

%.js: %.coffee
	coffee -cb $<
