clean: 
	rm -rf .nextflow*
	rm -rf work
	rm -rf results

test:
	nextflow run main.nf --xenium_path data --tile.width 600 -resume


cleantest: clean test