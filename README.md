# bifrost_amrfinderplus

This is the repository of the implementation of [NCBI Antimicrobial Resistance Gene Finder (AMRFinderPlus)](https://github.com/ncbi/amr) on bifrost.
AMRFinderPlus finds acquired antimicrobial resistance genes and some point mutations in protein or assembled nucleotide sequences.

**NOTE: Please be aware that this is a draft. The component hasn't been tested and it doesn't work yet.**

## How to launch - draft
```bash
git clone https://github.com/ssi-dk/bifrost_amrfinderplus
cd bifrost_amrfinderplus
bash install.sh -i LOCAL
conda activate bifrost_amrfinderplus_vx.x.x
export BIFROST_INSTALL_DIR='/your/path/'
BIFROST_DB_KEY="/your/key/here/" python -m bifrost_amrfinderplus -h
```
