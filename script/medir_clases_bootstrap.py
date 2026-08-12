import re, glob, collections, json

def names_from(text, scss=False):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    if scss:                      # solo en SCSS: y solo al principio de linea
        text = re.sub(r"^\s*//[^\n]*", "", text, flags=re.M)
    out = set()
    for sel in re.findall(r"([^{}]+)\{", text):
        out.update(re.findall(r"\.(-?[_a-zA-Z][\w-]*)", sel))
    return out

def css(path): return names_from(open(path, encoding="utf-8", errors="ignore").read())
def sass_tree(pattern):
    out = set()
    for f in glob.glob(pattern):
        out |= names_from(open(f, encoding="utf-8", errors="ignore").read(), scss=True)
    return out

BS2 = sass_tree("/home/imanol/RubymineProjects/hobo_apps/hobo2_amenti/lib/bootstrap-sass-4de54be4dd53/vendor/assets/stylesheets/bootstrap/*.scss")
BS3 = css("/mnt/e/APSOFT/UnoyCero/aplicaciones/2.3.1/chatty/vendor/assets/stylesheets/bootstrap.css")
BS5 = css("/home/imanol/RubymineProjects/hobo_oficial_2027/hobo_bootstrap/app/assets/stylesheets/bootstrap.css")
print(f"clases definidas  BS2: {len(BS2)}   BS3: {len(BS3)}   BS5: {len(BS5)}")
for probe in ["btn", "active", "modal-body", "carousel-item", "float-end", "d-none", "col-md-5"]:
    print(f"   BS5 tiene '{probe}': {probe in BS5}")

templates = glob.glob("/mnt/e/APSOFT/UnoyCero/aplicaciones/**/*.dryml", recursive=True)
used, files = collections.Counter(), collections.defaultdict(set)
for t in templates:
    try: text = open(t, encoding="utf-8", errors="ignore").read()
    except OSError: continue
    for m in re.findall(r'class=["\']([^"\']*)["\']', text):
        for n in m.split():
            if re.match(r"^[a-zA-Z][\w-]*$", n):
                used[n] += 1; files[n].add(t)

old = BS2 | BS3
gone = {n: c for n, c in used.items() if n in old and n not in BS5}
only2 = {n for n in gone if n in BS2 and n not in BS3}
icons = {n for n in gone if n.startswith("icon-")}
print(f"\nplantillas: {len(templates)}   clases escritas distintas: {len(used)}")
print(f"se rompen (estaban en BS2/BS3, no en BS5): {len(gone)}  ({sum(gone.values())} apariciones)")
print(f"   de esas, iconos: {len(icons)}   murieron ya en 2->3: {len(only2)}")
json.dump({"gone": gone, "only2": sorted(only2), "icons": sorted(icons)},
          open("/home/imanol/.claude/jobs/956f4927/tmp/medida.json", "w"))
print("\nsin contar iconos, por uso:")
for n, c in sorted(((n, c) for n, c in gone.items() if n not in icons), key=lambda x: -x[1]):
    print(f"  {c:5d}  {n:20s} {'2->3' if n in only2 else '3->5'}  ({len(files[n])} ficheros)")
