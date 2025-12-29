process LOGAN_GENOMAD {
    tag "${meta.id}"
    label 'process_super_high'
    maxForks 100
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/b0/b0fbdf77eb8d37f15eb61ec05159f0d862f48bc7beb2ac34303972f1dba43119/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-cbd9ffe41f9a6d49_1?_gl=1*14ltsrk*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..

    input:
    tuple val(meta), val(urls)
    path(genomad_db)

    output:
    tuple val(meta), path("${meta.id}_virus.fna.gz")            , emit: fna_gz
    tuple val(meta), path("${meta.id}_virus_summary.tsv.gz")    , emit: summary_tsv_gz
    tuple val(meta), path("${meta.id}_virus_genes.tsv.gz")      , emit: genes_tsv_gz
    path "versions.yml"                                         , emit: versions

    script:
    def url_list        = urls.collect { sample_url -> sample_url[2].toString() }.join(',')
    """
    # create arrays to iterate over
    IFS=',' read -r -a url_array <<< "${url_list}"

    ### Download logan assemblies
    printf "%s\n" "\${url_array[@]}" | xargs -I{} -n 1 -P ${task.cpus} bash -c \\
    'aws s3 cp {} tmp --no-sign-request'

    ### Remove short contigs
    mkdir -p tmp/
    seqkit \\
        seq \\
        --threads ${task.cpus} \\
        --min-len ${params.classify_min_length} \\
        tmp/*.fa.* \\
        --out-file combined_filtered.fasta.gz

    rm tmp/

    ### Identify viruses ###
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
        awscli: \$( aws --version | sed 's/aws-cli\\///; s/ Python.*//' )
        seqkit: \$(seqkit version | cut -d' ' -f2)
        genomad: \$(echo \$(genomad --version 2>&1) | sed 's/^.*geNomad, version //; s/ .*\$//')
    END_VERSIONS
    """
}
