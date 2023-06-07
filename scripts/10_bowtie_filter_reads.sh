#! /bin/bash

# PARSE ARGUMENTS ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --idx)
            idx="$2"
            echo "Found index location..."
            shift 2
            ;;
        --dir-input)
            dir_input="$2"
            echo "Found input directory..."
            shift 2
            ;;
        --dir-unmapped-single)
            dir_unmapped_single="$2"
            echo "Found unmapped single read directory..."
            shift 2
            ;;
        --dir-unmapped-pair)
            dir_unmapped_pair="$2"
            echo "Found unmapped paired read directory..."
            shift 2
            ;;
        --dir-aligned)
            dir_aligned="$2"
            echo "Found aligned result directory..."
            shift 2
            ;;
        --n-threads)
            nthreads="$2"
            echo "Found number of assigned threads..."
            shift 2
            ;;
        *)
            if [[ "$1" =~ ^--.*$ ]]; then
                echo "Argument '$1' requires a value."
            else
                echo "Invalid argument: $1"
            fi
            exit 1
            ;;
    esac
done

# READ INPUT FILES ---
input_files=$(ls ${dir_input}*fastq.gz)

# LOGGING ---
echo "Running form directory: $PWD"
echo "Input File Location: $dir_input"
echo "Results (Unmapped Single Sequences): $dir_unmapped_single"
echo "Results (Unmapped Paired Sequences): $dir_unmapped_pair"
echo "Results (Aligned): $dir_aligned"
echo "Input files: $input_files"

# CREATE PAIRED READS ---

# Associative array to store file pairs
declare -A file_pairs

# Loop through each input file
for file in $input_files; do
    # Extract the ID up to the fourth "_" occurrence
    id=$(echo "$file" | cut -d "_" -f 1-4)
    
    # Extract the suffix (R1 or R2) from the file name
    suffix=$(echo "$file" | awk -F "_" '{print $4}')

    # Check if the ID exists in the file_pairs array
    if [[ ${file_pairs[$id]} ]]; then
        # Append the current file to the existing entry in the array
        file_pairs[$id]+=" $file"
    else
        # Create a new entry in the array for the ID
        file_pairs[$id]="$file"
    fi
done

# FILTER READS ---

# Loop through the file pairs and perform your desired operations
for id in "${!file_pairs[@]}"; do

    # Get the pair of files for the current ID
    files="${file_pairs[$id]}"

    # Create the file id without the path prefix
    id_trim="${id##*/}"
    # id_trim=$(echo "$id" | cut -d "/" -f 3)
    echo "Filtering sample: $id_trim"

    IFS=" " read -ra substrings <<< "$files"
    for substring in "${substrings[@]}"; do

        if $(echo "$substring" | grep -q "R1"); then
            file_r1=$substring
        else
            file_r2=$substring
        fi
    done

    bowtie2 \
        -p $nthreads \
        -x $idx \
        -1 $file_r1 \
        -2 $file_r2 \
        --un-conc-gz "${dir_unmapped_pair}/${id_trim}_UNMAPPED_%.fastq.gz" \
        -S "${dir_aligned}/${id_trim}.sam" 2> "results/logs/${id_trim}.log"
    
    echo "Converting SAM to BAM form ${id_trim}"

    samtools view \
        -h \
        -b ${dir_aligned}/${id_trim}.sam > \
        ${dir_aligned}/${id_trim}.bam
    rm ${dir_aligned}/${id_trim}.sam

    # Filter not paired but single Sequences
    samtools view -b -h -f 12 -F 256 \
       ${dir_aligned}/${id_trim}.bam \
       > ${dir_unmapped_single}/${id_trim}.bam

    echo "Finished File!"

done

echo "Finished All Files!"
exit 0
