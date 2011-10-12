%.rom.js: roms/%.rom
	echo Convert $< to $@

%.js: %.coffee
	coffee -cb $<

all:: cpu.js os12.rom.js
