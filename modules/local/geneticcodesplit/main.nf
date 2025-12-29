process GENETICCODE_SPLIT {
    tag "${meta.id}"
    label 'process_low'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/cb/cbf0b946c283ddce3e949a7c6e5e80c2c965df35f8cae0ecf9078ed25dfcf110/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-0f2e218bda59ee6b_1?_gl=1*fcksx4*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTg0OTY4ODYzMC4xNzY1NDA0Njk5LjE3NjU0MDQ2OTk.

    input:
    tuple val(meta), path(fna), path(tsv)

    output:
    tuple val(meta), path("${meta.id}_gcode*.fna.zst")  , emit: fna_zst
    path("versions.yml")                                , emit: versions

    script:
    """
    # split input fasta into smaller chunks
    genetic_code_split.py \\
        --input ${tsv} \\
        --output ${meta.id} \\
        --g_code_column genetic_code \\
        --name_column seq_name
    
    # split fna into separate files based on genetic code
    for file in ${meta.id}_gcode*.tsv; do
        code=\$(echo \${file} | sed -E 's/.*_gcode([0-9]+).tsv/\\1/')

        seqkit grep \\
            ${fna} \\
            --pattern-file \${file} \\
            --out-file ${meta.id}_gcode\${code}.fna.zst
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$( python --version | sed -e "s/Python //g" )
        polars: \$(python -c "import polars; print(polars.__version__)")
        seqkit: \$(echo \$(seqkit 2>&1) | sed 's/^.*Version: //; s/ .*\$//')
    END_VERSIONS
    """
}
