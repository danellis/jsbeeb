FONTS=fonts/ttext-grc-ldh.png fonts/ttext-grc-udh.png fonts/ttext-grc.png fonts/ttext-grs-ldh.png fonts/ttext-grs-udh.png fonts/ttext-grs.png fonts/ttext-std-ldh.png fonts/ttext-std-udh.png fonts/ttext-std.png

all:: cpu.js os12.rom.js basic2.rom.js $(FONTS)

fonts/%.png: fonts/%.bdf
	tools/mkfontbitmap.py $< $@

os12.rom.js: roms/os12.rom
	tools/convert_rom.py roms/os12.rom os12.rom.js os_rom

basic2.rom.js: roms/basic2.rom
	tools/convert_rom.py roms/basic2.rom basic2.rom.js basic_rom

%.js: %.coffee
	coffee -cb $<
