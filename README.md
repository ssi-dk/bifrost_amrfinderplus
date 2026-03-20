# bifrost_amrfinderplus

This component is used to find acquired antimicrobial resistance genes and some point mutations in protein or assembled nucleotide sequences. The component is limited to a predefined set of species native to the utilized tool (described below). 

## Requirements
- The component uses data which is either an uploaded assembled sequence (event data), which has been filtered through one [component](https://github.com/ssi-dk/bifrost_assembly_qc), or using the generated *de novo* assembly from the [component](https://github.com/ssi-dk/bifrost_assemblatron/)
- The component uses the NCBI Antimicrobial Resistance Gene Finder tool [AMRfinderplus](https://github.com/ncbi/amr).
- The versions are described in the [environment.yaml](https://github.com/ssi-dk/bifrost_amrfinderplus/blob/Dev/environment.yml)
- The AMRfinderplus tool performs species-specific analysis to optimize organism-specific results on a defined set of [organisms](https://github.com/ncbi/amr/wiki/Curated-organisms). If the dataset is uploaded assemblies, the provided species is used as an option for the tool, whereas the *de novo* generated assembly data utilize the species determined from another [component](https://github.com/ssi-dk/bifrost_whats_my_species).

## Download
```bash
git clone https://github.com/ssi-dk/bifrost_amrfinderplus.git
cd bifrost_amrfinderplus
git submodule init
git submodule update
bash install.sh -i LOCAL
conda activate bifrost_amrfinderplus_vx.x.x
export BIFROST_INSTALL_DIR='/your/path/'
BIFROST_DB_KEY="/your/key/here/" python -m bifrost_amrfinderplus -h
```

## Run the snakemake analysis
Each component can be run on a single sample using a single snakemake command, replacing the string passed to the **--config sample_name=" "** with the appropriate dataset name. The provided **component_name=** takes as an argument *<component_name>__<version_number>*. The component name aligns with the GitHub repo name, which is structured like *bifrost_<component_name>* (e.g. *bifrost_amrfinderplus* -> component name *amrfinderplus*), and the version number aligns with the current [GitHub tag](https://github.com/ssi-dk/bifrost_amrfinderplus/tags) / or conda environment [version](https://github.com/ssi-dk/bifrost_amrfinderplus/blob/main/setup.py) (e.g. *v.1.0.0*) defined during the bifrost component setup. 
```bash
snakemake -p --nolock --cores all -s <github path>/pipeline.smk --config sample_name="insert sample name" component_name=amrfinderplus__v1.0.0 --rerun-incomplete
```

## Add a species
The inferred species from a different [component](https://github.com/ssi-dk/bifrost_whats_my_species) needs to be mapped to a format specified by the amrfinderplus parameter *-O*. To add species to this component, the dictionary *amrfinderplus_organism_option* in file [config.yaml](https://github.com/ssi-dk/bifrost_amrfinderplus/blob/main/bifrost_amrfinderplus/config.yaml) needs to be opdated, with the key's fitting the inferred species name, and the value fitting the AMRfinderplus [organisms](https://github.com/ncbi/amr/wiki/Curated-organisms). 

