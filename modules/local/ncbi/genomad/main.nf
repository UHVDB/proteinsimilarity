process NCBI_GENOMAD {
    tag "${meta.id}"
    label 'process_high'
    maxForks 100
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/97/978204c87f2f4e8441499e2240ac4a9b3612e2373cb7d9b3acb9ea0bd2d38080/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-7663fcb5c1f21741_1?_gl=1*1h4qz3k*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..

    input:
    tuple val(meta), val(urls)
    path(genomad_db)

    output:
    tuple val(meta), path("${meta.id}_virus.fna.gz")            , emit: fna_gz
    tuple val(meta), path("${meta.id}_virus_genes.tsv.gz")      , emit: genes_tsv_gz
    tuple val(meta), path("${meta.id}_virus_summary.tsv.gz")    , emit: summary_tsv_gz
    path "versions.yml"                                         , emit: versions

    script:
    def download_list   = urls.collect { sample_url -> sample_url[2].toString() + ',\sout=' + sample_url[1].toString() + '.fna.gz' }.join(',')
    """
    # download ncbi assemblies
    IFS=',' read -r -a download_array <<< "${download_list}"
    printf '%s\\n' "\${download_array[@]}" > aria2_file.tsv

    aria2c \\
        --input=aria2_file.tsv \\
        --dir=tmp/download \\
        --max-connection-per-server=${task.cpus} \\
        --split=${task.cpus} \\
        --max-tries=10 \\
        --retry-wait=30 \\
        --max-concurrent-downloads=${task.cpus}

    rm aria2_file.tsv

    # remove short contigs
    seqkit \\
        seq \\
        --threads ${task.cpus} \\
        --min-len ${params.classify_min_length} \\
        tmp/download/* \\
        --out-file combined_filtered.fasta.gz

    rm -rf tmp/download/

    # identify viruses
    genomad \\
        end-to-end \\
        combined_filtered.fasta.gz \\
        ./ \\
        ${genomad_db} \\
        --threads ${task.cpus} \\
        ${params.classify_genomad_args}

    # save virus outputs
    gzip -c *_summary/*_virus.fna > ${meta.id}_virus.fna.gz
    gzip -c *_summary/*_virus_summary.tsv > ${meta.id}_virus_summary.tsv.gz
    gzip -c *_summary/*_virus_genes.tsv > ${meta.id}_virus_genes.tsv.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        aria2: \$(echo \$(aria2c --version 2>&1) | grep 'aria2 version' | cut -f3 -d ' ')
        seqkit: \$(seqkit version | cut -d' ' -f2)
        genomad: \$(echo \$(genomad --version 2>&1) | sed 's/^.*geNomad, version //; s/ .*\$//')
    END_VERSIONS
    """
}
