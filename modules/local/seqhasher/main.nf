process SEQHASHER {
    tag "${meta.id}"
    label 'process_medium'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/c0/c01afbd21a56c8c6e33e1bfa161f157d9b31f2307a0896f97515139f79fb9cd3/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-468ffa5c279199c2_1?_gl=1*m9en3t*_gcl_au*NTUzODYxMTI2LjE3Njc2NTE5OTY.
    
    input:
    tuple val(meta), path(fasta)
    val(rename)

    output:
    tuple val(meta), path("${meta.id}.seqhasher.tsv.gz") , emit: tsv_gz

    script:
    """
    ### Add prefix
    if [ "${rename}" = "true" ]; then
        seqkit \\
            replace \\
            ${fasta} \\
            --pattern "^" \\
            --replacement "${meta.id}_" \\
            --out-file renamed_${fasta}
    else
        cp ${fasta} renamed_${fasta}
    fi

    ### Trim DTRs
    tr-trimmer \\
        renamed_${fasta} \\
        --min-length 20 \\
        --include-tr-info \\
        > ${meta.id}.trtrimmer.fna

    ### Calculate sequence hashes
    seq-hasher \\
        ${meta.id}.trtrimmer.fna \\
        --multi-kmer-hashing \\
        --circular-kmers \\
        --print-sequence \\
        > ${meta.id}.seqhasher.tsv

    ### Compress output
    pigz -p ${task.cpus} ${meta.id}.seqhasher.tsv

    ### Cleanup
    rm -rf renamed_${fasta} ${meta.id}.trtrimmer.fna
    """
}
