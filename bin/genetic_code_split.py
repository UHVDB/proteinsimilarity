#!/usr/bin/env python

import argparse
import polars as pl

def parse_args(args=None):
    description = "Split geNomad or genetic code TSV into multiple files using the same genetic code."
    epilog = "Example usage: python genetic_code_split.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-i",
        "--input",
        help="Path to input TSV file.",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Prefix for output TSV files.",
    )
    parser.add_argument(
        "-g",
        "--g_code_column",
        help="Column containing genetic code information.",
    )
    parser.add_argument(
        "-n",
        "--name_column",
        help="Column containing sequence names.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)



def main(args=None):
    args = parse_args(args)

    # load genetic code TSV
    df = pl.read_csv(args.input, separator='\t')

    # identify different genetic codes in the input TSV
    genetic_codes = (
        df.select(args.g_code_column).unique().to_series().to_list()
    )

    # save separate TSV files for each genetic code
    for code in genetic_codes:
        output_path = f"{args.output}_gcode{code}.tsv"
        (
            df
                .filter(pl.col(args.g_code_column).cast(pl.Int64) == int(code))
                [[args.name_column]]
                .write_csv(output_path, separator='\t', include_header=False)
        )

if __name__ == "__main__":
    main()
