from datetime import datetime
from transmission_rpc import Client
import argparse
import json

parser = argparse.ArgumentParser(
    description="Change the transmission root torrent path"
)
parser.add_argument("--host", help="Host name of the transmission server")
parser.add_argument("--username", help="Username of the transmission server")
parser.add_argument("--password", help="Password of the transmission server")
parser.add_argument("--old-path", help="The old root path of transmission torrent")
parser.add_argument(
    "--new-path",
    help="The new root path of the transmission torrent. Must not contain the old path in it",
)
parser.add_argument(
    "--port", type=int, default=443, help="Port of the transmission server"
)
parser.add_argument(
    "--dry-run", action="store_true", help="Print the result of the run only"
)
parser.add_argument(
    "--protocol",
    default="https",
    help="Protocol of the transmission host",
)
parser.add_argument(
    "--output-json-file",
    default=".decrypted.transmission",
    help="Output the file state to json",
)

args = parser.parse_args()
c = Client(
    protocol=args.protocol,
    host=args.host,
    port=args.port,
    username=args.username,
    password=args.password,
)

if args.new_path.__contains__(args.old_path):
    print(
        f"Be careful for path replacement since new path: {args.new_path} contain old path: {args.old_path}. Forcing dry-run"
    )
    args.dry_run = True

torrent_list = c.get_torrents()
torrent_dict = {}

for torrent in torrent_list:
    if args.old_path in torrent.download_dir:
        new_dir = torrent.download_dir.replace(args.old_path, args.new_path, 1)
        torrent_dict[torrent.id] = {
            "name": torrent.name,
            "old_path": torrent.download_dir,
            "new_path": new_dir,
        }
        if not args.dry_run:
            c.locate_torrent_data(ids=torrent.id, location=new_dir)

now = datetime.utcnow().strftime("%Y-%m-%d_%H-%M-%S")
out_file = open(f"{args.output_json_file}.{now}.json", "w")
jsonStr = json.dump(torrent_dict, out_file, sort_keys=True, indent=2)
out_file.close()
