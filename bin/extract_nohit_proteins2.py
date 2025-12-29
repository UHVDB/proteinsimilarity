#!/usr/bin/env python

import argparse

from Bio import SeqIO
import pandas as pd

def parse_args(args=None):
    description = "Identify and extract proteins without a UniProt hit from Bakta or Foldseek."
    epilog = "Example usage: python extract_nohit_proteins2.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-i",
        "--input_gbk",
        help="Path to input GBK file produced by Bakta.",
    )
    parser.add_argument(
        "-f",
        "--input_tsv",
        help="Path to input hypotheticals TSV file produced by foldseek.",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Name for output GBK file.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)



def main(args=None):
    args = parse_args(args)

    # load Foldseek hits
    foldseek_hits = set(
        pd.read_csv(args.input_tsv, sep='\t', header=None)[0]
    )

    # identify proteins without UniProt hit from Bakta or Foldseek
    loci_wo_hits = []
    for record in SeqIO.parse(args.input_gbk, 'genbank'):
        for f in record.features:
            if f.type == 'CDS' and f.qualifiers.get('locus_tag', [None])[0] not in foldseek_hits and f.qualifiers.get('db_xref', [None])[0] is not None:
                loci_wo_hits.append(f.qualifiers.get('locus_tag', [None])[0])

    # identify proteins without UniProt hit from Bakta or Foldseek
    records_wo_hits = []
    for record in SeqIO.parse(args.input_gbk, 'genbank'):
        record.features = [
            f for f in record.features
            if (f.type == 'gene' or f.type == 'CDS')
            and f.qualifiers.get('locus_tag', [None])[0] in loci_wo_hits
        ]
        if len(record.features) > 0:
            records_wo_hits.append(record)

    SeqIO.write(records_wo_hits, args.output, 'genbank')

if __name__ == "__main__":
    main()
