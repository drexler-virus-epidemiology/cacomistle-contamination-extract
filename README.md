# Vi-fi of unmapped ringtail reads

The task is to extract reads not mapped to several viruses from NovaSeq reads
from cacomistle/ringtail samples and use them as inputs for the
virus-discovery-pipeline.

## Known contaminations

The samples contain sequences of four viruses that are not of interest for this
analysis. Reads matching them should be removed from further analysis.

* Paper: Natural co-infection of divergent hepatitis B and C virus homologues
  in carnivores[DOI](https://doi.org/10.1111/tbed.14340)
* Ringtail hepacivirus: 
    * Accession: MZ393518.1, GI: 2106717912
    * Accession: MZ393517.1, GI: 2106717910
    * [NCBI Link](https://www.ncbi.nlm.nih.gov/nuccore/?term=ringtail+hepacivirus)
* Ringtail hepadnavirus:
    * Accession: MZ397304.1, GI: 2106717930
    * Accession: MZ397303.1, GI: 2106717922
    * Accession: MZ393519.1, GI: 2106717914
    * [NCBI Link](https://www.ncbi.nlm.nih.gov/nuccore/?term=ringtail+hepadnavirus)
* Canine distemper virus/Canine morbillivirus:
    * Assembly: [`ViralProj15002`](https://www.ncbi.nlm.nih.gov/assembly/GCF_000854065.1/)
    * RefSeq: [`NC_001921.1`](https://www.ncbi.nlm.nih.gov/nuccore/NC_001921.1/)
* Severe acute respiratory syndrome coronavirus 2 (SARS-CoV-2):
    * Assembly: [`ASM985889v3`](https://www.ncbi.nlm.nih.gov/assembly/GCF_009858895.2)
    * RefSeq: [`NC_045512.2`](https://www.ncbi.nlm.nih.gov/nuccore/1798174254)

A list of the accession IDs for each can be found in `data/known_sequences`

## Download sequences

The expected output of the program is shown after `#> `.

```
# Start a terminal from the project root. This should be the location
tree .
#> .
#> ├── archive
#> ├── data
#> │   └── known_sequences
#> ├── documents
#> ├── literature
#> ├── paper
#> ├── README.md
#> ├── results
#> ├── scripts
#> │   └── 00_download_known_accession_sequences.sh
#> ├── sent
#> └── temp

# Download the entrez-direct tools and install
# them into a new conda environment
conda env create -n entreztools -c bioconda entrez-direct
conda activate entreztools 

# Run the provided script to download the accessions
./00_download_known_accession_sequences.sh

# Check for the accessions in the result file
cat results/known_sequences.fasta | grep "^>"
#> >MZ393518.1 Ringtail hepacivirus isolate CO-09/924, complete genome
#> >MZ393517.1 Ringtail hepacivirus isolate CO-08/923, complete genome
#> >MZ397304.1 Ringtail hepadnavirus isolate CO-11/926, complete genome
#> >MZ397303.1 Ringtail hepadnavirus isolate CO-08/923, complete genome
#> >MZ393519.1 Ringtail hepadnavirus isolate CO-09/924, complete genome
#> >NC_001921.1 Canine distemper virus, complete genome
#> >NC_045512.2 Severe acute respiratory syndrome coronavirus 2 isolate Wuhan-Hu-1, complete genome
```

## Use `Bowtie2` to separate known and unknown sequences

* First create index using `bowtie2-build`.
* Create a conda environment with `conda create -c bioconda -n bowtie bowtie2=2.5.1`
* Activate the environment with `conda activate bowtie`
* Install samtolls to convert SAM to BAM: `conda install samtools`
```
# Create index and direct output to a nohup.out log-file
mkdir results/bowtie_index
nohup bowtie2-build \
    results/known_sequences.fasta \ # <reference_in> 
    results/bowtie_index/reference_index # <bt2_index_base>

# Save the log file
mv nohup.out results/bowtie_index/bowtie2-build.log
```

* Create a link to the directory containing the data (symlink)
* Do some checks:
    * Check on how many files are present: `ls | wc -l`
    * Check the number of files for each sample: `ls | cut -d "_" -f 3 |  uniq
      -c`
    * Check the total number of unique files per sample: `ls | \ cut -d "_" -f
      3 | \ uniq -c | \ awk '{ print $1 }' | \ sort | \ uniq -c`
    * I have 96 samples with four files each: `L001_R1`, `L001_R2`, `L002_R1`,
      `L002_R2`

```
# Create a symbolic link to the folder containing the data (!MODIFY)
READ_LOCATION='/home/carl/mnt-hpc-transfer/fast/work/groups/ag-drexler/novaseq1reads'
ln -s $READ_LOCATION data/reads

# Check total number of files
ls data/reads/ | wc -l
#> 384

# Check number of files per sample (ID is S1..S96)
ls data/reads | \
    cut -d "_" -f 3 | \ 
    uniq -c | \
    awk '{ print $1 }' | \
    sort | \
    uniq -c
#> 96 4
```

* Use bowtie to create alignment SAM files for each paired-end sample. Note
  that for each sample, reads from two lanes exist, so the ID extends to the
  lane ID, e. g. `20099a002_01_S1_L001_R1`
* Using the flag `--un-conc-gz` allows for automatic filtering of unmapped
  reads to skip the additonal filtering step using `samtools` (read about it
  [here](https://www.metagenomics.wiki/tools/short-read/remove-host-sequences))
* Deposit the project folder somewhere on the cluster (e.g. your `work/` drive)
* Make the scripts executable using `chmod`
* Submit the job `filter_reads.job` script to the scheduler

```
# Make sure scripts are executable
chmod ug+x ./scripts/*

# Modify the job script to fit your analysis needs 
cat filter_reads.job

# Submit the script to the scheduler
sbatch filter_reads.job
```

The filtered results can be found in the `$MAPPED` and `$UNMAPPED` folders.

To clone the local folder to the remote location use `rclone`

```
# Select a fitting path to the project folder on the cluster
PATH_TO_PROJECT="/home/carl/mnt-hpc-transfer/data/gpfs-1/users/cabe12_c/projects"

# Sync the local project folder to a directory on the cluster
rclone sync \ 
    2305_wendy_novaseq_cacomistle_extract/ \
    ${PATH_TO_PROJECT}/2305_wendy_novaseq_cacomistle_extract/
```
