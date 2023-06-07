#! /bin/bash

# Usage:
# Activate the conda environment containing the entrez-direct tools
# conda activate entreztools

# File containing accession numbers
ACCESSION_LIST='./data/known_sequences'

# The result file containing the sequences 
ACCESSION_FASTA='./results/known_sequences.fasta'

# Clear the file
> "$ACCESSION_FASTA"

while IFS= read -r accession_id <&3; do
    echo "Downloading $accession_id..."
    esearch -db nucleotide -query "$accession_id" | \
        efetch -format fasta \
        >> "$ACCESSION_FASTA"
done 3< "$ACCESSION_LIST"
