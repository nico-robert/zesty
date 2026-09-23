namespace eval zesty {
    variable tcolor {}
}

# 256 Extended Colors Correspondence (8-bit)
# 1. Standard Colors (0-15)

dict set zesty::tcolor 0  {name Black           hex "#000000"}
dict set zesty::tcolor 1  {name Red             hex "#800000"}
dict set zesty::tcolor 2  {name Green           hex "#008000"}
dict set zesty::tcolor 3  {name Yellow          hex "#808000"}
dict set zesty::tcolor 4  {name Blue            hex "#000080"}
dict set zesty::tcolor 5  {name Magenta         hex "#800080"}
dict set zesty::tcolor 6  {name Cyan            hex "#008080"}
dict set zesty::tcolor 7  {name {Light Gray}    hex "#c0c0c0"}
dict set zesty::tcolor 8  {name Gray            hex "#808080"}
dict set zesty::tcolor 9  {name {Light Red}     hex "#ff0000"}
dict set zesty::tcolor 10 {name {Light Green}   hex "#00ff00"}
dict set zesty::tcolor 11 {name {Light Yellow}  hex "#ffff00"}
dict set zesty::tcolor 12 {name {Light Blue}    hex "#0000ff"}
dict set zesty::tcolor 13 {name {Light Magenta} hex "#ff00ff"}
dict set zesty::tcolor 14 {name {Light Cyan}    hex "#00ffff"}
dict set zesty::tcolor 15 {name White           hex "#ffffff"}

# 2. 6x6x6 Color Palette (16-231)

dict set zesty::tcolor 16 {name Black2                   hex "#000000"}
dict set zesty::tcolor 17 {name {Dark Navy Blue}         hex "#00005f"}
dict set zesty::tcolor 18 {name {Navy Blue}              hex "#000087"}
dict set zesty::tcolor 19 {name {Dark Royal Blue}        hex "#0000af"}
dict set zesty::tcolor 20 {name {Royal Blue}             hex "#0000d7"}
dict set zesty::tcolor 21 {name {Bright Blue}            hex "#0000ff"}
dict set zesty::tcolor 22 {name {Dark Green}             hex "#005f00"}
dict set zesty::tcolor 23 {name {Dark Blue-Green}        hex "#005f5f"}
dict set zesty::tcolor 24 {name Blue-Green               hex "#005f87"}
dict set zesty::tcolor 25 {name {Medium Blue}            hex "#005faf"}
dict set zesty::tcolor 26 {name {Medium Pure Blue}       hex "#005fd7"}
dict set zesty::tcolor 27 {name {Light Pure Blue}        hex "#005fff"}
dict set zesty::tcolor 28 {name {Forest Green}           hex "#008700"}
dict set zesty::tcolor 29 {name {Dark Green-Blue}        hex "#00875f"}
dict set zesty::tcolor 30 {name {Dark Turquoise}         hex "#008787"}
dict set zesty::tcolor 31 {name {Deep Turquoise}         hex "#0087af"}
dict set zesty::tcolor 32 {name {Deep Sky Blue}          hex "#0087d7"}
dict set zesty::tcolor 33 {name {Sky Blue}               hex "#0087ff"}
dict set zesty::tcolor 34 {name {Dark Lime Green}        hex "#00af00"}
dict set zesty::tcolor 35 {name {Emerald Green}          hex "#00af5f"}
dict set zesty::tcolor 36 {name Green-Turquoise          hex "#00af87"}
dict set zesty::tcolor 37 {name Turquoise                hex "#00afaf"}
dict set zesty::tcolor 38 {name {Light Sky Blue}         hex "#00afd7"}
dict set zesty::tcolor 39 {name {Azure Blue}             hex "#00afff"}
dict set zesty::tcolor 40 {name {Lime Green}             hex "#00d700"}
dict set zesty::tcolor 41 {name {Spring Green}           hex "#00d75f"}
dict set zesty::tcolor 42 {name {Mint Green}             hex "#00d787"}
dict set zesty::tcolor 43 {name {Light Turquoise}        hex "#00d7af"}
dict set zesty::tcolor 44 {name {Medium Cyan}            hex "#00d7d7"}
dict set zesty::tcolor 45 {name {Bright Cyan}            hex "#00d7ff"}
dict set zesty::tcolor 46 {name {Bright Green}           hex "#00ff00"}
dict set zesty::tcolor 47 {name {Chartreuse Green}       hex "#00ff5f"}
dict set zesty::tcolor 48 {name {Bright Spring Green}    hex "#00ff87"}
dict set zesty::tcolor 49 {name {Aqua Green}             hex "#00ffaf"}
dict set zesty::tcolor 50 {name {Bright Turquoise}       hex "#00ffd7"}
dict set zesty::tcolor 51 {name {Light Cyan2}            hex "#00ffff"}
dict set zesty::tcolor 52 {name {Dark Brown}             hex "#5f0000"}
dict set zesty::tcolor 53 {name Burgundy                 hex "#5f005f"}
dict set zesty::tcolor 54 {name {Dark Indigo}            hex "#5f0087"}
dict set zesty::tcolor 55 {name {Dark Violet}            hex "#5f00af"}
dict set zesty::tcolor 56 {name Violet                   hex "#5f00d7"}
dict set zesty::tcolor 57 {name {Pure Violet}            hex "#5f00ff"}
dict set zesty::tcolor 58 {name {Dark Olive}             hex "#5f5f00"}
dict set zesty::tcolor 59 {name {Dark Gray}              hex "#5f5f5f"}
dict set zesty::tcolor 60 {name Blue-Gray                hex "#5f5f87"}
dict set zesty::tcolor 61 {name Gray-Blue                hex "#5f5faf"}
dict set zesty::tcolor 62 {name {Dark Lavender}          hex "#5f5fd7"}
dict set zesty::tcolor 63 {name Lavender                 hex "#5f5fff"}
dict set zesty::tcolor 64 {name {Medium Olive}           hex "#5f8700"}
dict set zesty::tcolor 65 {name {Olive Green}            hex "#5f875f"}
dict set zesty::tcolor 66 {name {Medium Gray}            hex "#5f8787"}
dict set zesty::tcolor 67 {name {Medium Gray-Blue}       hex "#5f87af"}
dict set zesty::tcolor 68 {name {Lavender Blue}          hex "#5f87d7"}
dict set zesty::tcolor 69 {name {French Blue}            hex "#5f87ff"}
dict set zesty::tcolor 70 {name {Bright Olive Green}     hex "#5faf00"}
dict set zesty::tcolor 71 {name {Sage Green}             hex "#5faf5f"}
dict set zesty::tcolor 72 {name Gray-Green               hex "#5faf87"}
dict set zesty::tcolor 73 {name {Medium Gray-Blue2}      hex "#5fafaf"}
dict set zesty::tcolor 74 {name {Powder Blue}            hex "#5fafd7"}
dict set zesty::tcolor 75 {name {Light Sky Blue2}        hex "#5fafff"}
dict set zesty::tcolor 76 {name {Dark Chartreuse}        hex "#5fd700"}
dict set zesty::tcolor 77 {name {Pale Green}             hex "#5fd75f"}
dict set zesty::tcolor 78 {name {Light Mint Green2}      hex "#5fd787"}
dict set zesty::tcolor 79 {name {Pale Turquoise3}        hex "#5fd7af"}
dict set zesty::tcolor 80 {name {Pale Sky Blue}          hex "#5fd7d7"}
dict set zesty::tcolor 81 {name {Light Blue2}            hex "#5fd7ff"}
dict set zesty::tcolor 82 {name {Light Lime Green2}      hex "#5fff00"}
dict set zesty::tcolor 83 {name {Light Pale Green}       hex "#5fff5f"}
dict set zesty::tcolor 84 {name {Bright Pale Green}      hex "#5fff87"}
dict set zesty::tcolor 85 {name {Pale Aqua Green}        hex "#5fffaf"}
dict set zesty::tcolor 86 {name {Pale Cyan}              hex "#5fffd7"}
dict set zesty::tcolor 87 {name {Light Cyan3}            hex "#5fffff"}
dict set zesty::tcolor 88 {name {Dark Red}               hex "#870000"}
dict set zesty::tcolor 89 {name {Dark Magenta}           hex "#87005f"}
dict set zesty::tcolor 90 {name {Dark Violet2}           hex "#870087"}
dict set zesty::tcolor 91 {name Violet2                  hex "#8700af"}
dict set zesty::tcolor 92 {name {Pure Violet2}           hex "#8700d7"}
dict set zesty::tcolor 93 {name {Electric Violet}        hex "#8700ff"}
dict set zesty::tcolor 94 {name Red-Brown                hex "#875f00"}
dict set zesty::tcolor 95 {name Brown                    hex "#875f5f"}
dict set zesty::tcolor 96 {name {Grayed Mauve}           hex "#875f87"}
dict set zesty::tcolor 97 {name Mauve                    hex "#875faf"}
dict set zesty::tcolor 98 {name {Light Mauve}            hex "#875fd7"}
dict set zesty::tcolor 99 {name {Bright Mauve}           hex "#875fff"}
dict set zesty::tcolor 100 {name Khaki                   hex "#878700"}
dict set zesty::tcolor 101 {name Brown-Olive             hex "#87875f"}
dict set zesty::tcolor 102 {name {Taupe Gray}            hex "#878787"}
dict set zesty::tcolor 103 {name {Grayed Lilac}          hex "#8787af"}
dict set zesty::tcolor 104 {name Lilac                   hex "#8787d7"}
dict set zesty::tcolor 105 {name Periwinkle              hex "#8787ff"}
dict set zesty::tcolor 106 {name {Bright Olive}          hex "#87af00"}
dict set zesty::tcolor 107 {name {Medium Olive Green}    hex "#87af5f"}
dict set zesty::tcolor 108 {name {Medium Sage Green}     hex "#87af87"}
dict set zesty::tcolor 109 {name {Light Gray-Green}      hex "#87afaf"}
dict set zesty::tcolor 110 {name {Pastel Blue}           hex "#87afd7"}
dict set zesty::tcolor 111 {name {Light Sky Blue3}       hex "#87afff"}
dict set zesty::tcolor 112 {name Yellow-Green            hex "#87d700"}
dict set zesty::tcolor 113 {name {Apple Green}           hex "#87d75f"}
dict set zesty::tcolor 114 {name {Pastel Green}          hex "#87d787"}
dict set zesty::tcolor 115 {name {Light Mint Green}      hex "#87d7af"}
dict set zesty::tcolor 116 {name {Pastel Turquoise}      hex "#87d7d7"}
dict set zesty::tcolor 117 {name {Pastel Sky Blue}       hex "#87d7ff"}
dict set zesty::tcolor 118 {name {Chartreuse Green2}     hex "#87ff00"}
dict set zesty::tcolor 119 {name {Lime Green2}           hex "#87ff5f"}
dict set zesty::tcolor 120 {name {Light Lime Green}      hex "#87ff87"}
dict set zesty::tcolor 121 {name {Pale Green1}           hex "#87ffaf"}
dict set zesty::tcolor 122 {name {Pale Turquoise1}       hex "#87ffd7"}
dict set zesty::tcolor 123 {name {Pale Blue}             hex "#87ffff"}
dict set zesty::tcolor 124 {name {Medium Red}            hex "#af0000"}
dict set zesty::tcolor 125 {name Red-Magenta             hex "#af005f"}
dict set zesty::tcolor 126 {name {Dark Magenta2}         hex "#af0087"}
dict set zesty::tcolor 127 {name Magenta1                hex "#af00af"}
dict set zesty::tcolor 128 {name {Bright Magenta}        hex "#af00d7"}
dict set zesty::tcolor 129 {name {Electric Violet2}      hex "#af00ff"}
dict set zesty::tcolor 130 {name {Burnt Orange}          hex "#af5f00"}
dict set zesty::tcolor 131 {name Red-Brown2              hex "#af5f5f"}
dict set zesty::tcolor 132 {name {Rose Mauve}            hex "#af5f87"}
dict set zesty::tcolor 133 {name Orchid                  hex "#af5faf"}
dict set zesty::tcolor 134 {name {Medium Orchid}         hex "#af5fd7"}
dict set zesty::tcolor 135 {name Amethyst                hex "#af5fff"}
dict set zesty::tcolor 136 {name Yellow-Orange           hex "#af8700"}
dict set zesty::tcolor 137 {name {Light Brown}           hex "#af875f"}
dict set zesty::tcolor 138 {name Taupe                   hex "#af8787"}
dict set zesty::tcolor 139 {name Pink-Violet             hex "#af87af"}
dict set zesty::tcolor 140 {name {Light Mauve2}          hex "#af87d7"}
dict set zesty::tcolor 141 {name {Light Violet}          hex "#af87ff"}
dict set zesty::tcolor 142 {name Yellow-Green2           hex "#afaf00"}
dict set zesty::tcolor 143 {name {Light Khaki}           hex "#afaf5f"}
dict set zesty::tcolor 144 {name {Light Taupe}           hex "#afaf87"}
dict set zesty::tcolor 145 {name {Medium Gray2}          hex "#afafaf"}
dict set zesty::tcolor 146 {name {Light Lilac}           hex "#afafd7"}
dict set zesty::tcolor 147 {name {Light Lavender}        hex "#afafff"}
dict set zesty::tcolor 148 {name {Bright Yellow-Green}   hex "#afd700"}
dict set zesty::tcolor 149 {name {Light Chartreuse}      hex "#afd75f"}
dict set zesty::tcolor 150 {name {Pale Green2}           hex "#afd787"}
dict set zesty::tcolor 151 {name {Light Green2}          hex "#afd7af"}
dict set zesty::tcolor 152 {name {Pale Turquoise2}       hex "#afd7d7"}
dict set zesty::tcolor 153 {name {Pale Blue2}            hex "#afd7ff"}
dict set zesty::tcolor 154 {name {Bright Yellow-Green2}  hex "#afff00"}
dict set zesty::tcolor 155 {name {Light Yellow-Green}    hex "#afff5f"}
dict set zesty::tcolor 156 {name {Pale Green3}           hex "#afff87"}
dict set zesty::tcolor 157 {name {Very Pale Green}       hex "#afffaf"}
dict set zesty::tcolor 158 {name {Very Pale Turquoise}   hex "#afffd7"}
dict set zesty::tcolor 159 {name {Very Pale Blue}        hex "#afffff"}
dict set zesty::tcolor 160 {name Red2                    hex "#d70000"}
dict set zesty::tcolor 161 {name Red-Pink                hex "#d7005f"}
dict set zesty::tcolor 162 {name {Dark Pink}             hex "#d70087"}
dict set zesty::tcolor 163 {name {Medium Magenta}        hex "#d700af"}
dict set zesty::tcolor 164 {name {Bright Magenta2}       hex "#d700d7"}
dict set zesty::tcolor 165 {name {Electric Magenta}      hex "#d700ff"}
dict set zesty::tcolor 166 {name Orange                  hex "#d75f00"}
dict set zesty::tcolor 167 {name Red-Orange              hex "#d75f5f"}
dict set zesty::tcolor 168 {name {Coral Pink}            hex "#d75f87"}
dict set zesty::tcolor 169 {name Pink                    hex "#d75faf"}
dict set zesty::tcolor 170 {name {Bright Pink}           hex "#d75fd7"}
dict set zesty::tcolor 171 {name Pink-Magenta            hex "#d75fff"}
dict set zesty::tcolor 172 {name {Light Orange}          hex "#d78700"}
dict set zesty::tcolor 173 {name Peach                   hex "#d7875f"}
dict set zesty::tcolor 174 {name {Pale Pink}             hex "#d78787"}
dict set zesty::tcolor 175 {name {Light Pink}            hex "#d787af"}
dict set zesty::tcolor 176 {name Pink-Mauve              hex "#d787d7"}
dict set zesty::tcolor 177 {name Mauve-Pink              hex "#d787ff"}
dict set zesty::tcolor 178 {name Gold                    hex "#d7af00"}
dict set zesty::tcolor 179 {name Beige-Brown             hex "#d7af5f"}
dict set zesty::tcolor 180 {name Beige                   hex "#d7af87"}
dict set zesty::tcolor 181 {name {Pale Pink1}            hex "#d7afaf"}
dict set zesty::tcolor 182 {name {Very Pale Pink}        hex "#d7afd7"}
dict set zesty::tcolor 183 {name {Light Lavender2}       hex "#d7afff"}
dict set zesty::tcolor 184 {name Yellow2                 hex "#d7d700"}
dict set zesty::tcolor 185 {name {Pale Yellow}           hex "#d7d75f"}
dict set zesty::tcolor 186 {name {Pale Beige}            hex "#d7d787"}
dict set zesty::tcolor 187 {name {Very Pale Beige}       hex "#d7d7af"}
dict set zesty::tcolor 188 {name {Light Gray2}           hex "#d7d7d7"}
dict set zesty::tcolor 189 {name {Very Pale Lavender}    hex "#d7d7ff"}
dict set zesty::tcolor 190 {name {Bright Yellow}         hex "#d7ff00"}
dict set zesty::tcolor 191 {name {Pale Yellow-Green}     hex "#d7ff5f"}
dict set zesty::tcolor 192 {name {Pale Yellow1}          hex "#d7ff87"}
dict set zesty::tcolor 193 {name {Very Pale Yellow}      hex "#d7ffaf"}
dict set zesty::tcolor 194 {name White-Green             hex "#d7ffd7"}
dict set zesty::tcolor 195 {name White-Blue              hex "#d7ffff"}
dict set zesty::tcolor 196 {name {Bright Red}            hex "#ff0000"}
dict set zesty::tcolor 197 {name {Bright Pink2}          hex "#ff005f"}
dict set zesty::tcolor 198 {name {Deep Pink}             hex "#ff0087"}
dict set zesty::tcolor 199 {name {Fuchsia Pink}          hex "#ff00af"}
dict set zesty::tcolor 200 {name Magenta2                hex "#ff00d7"}
dict set zesty::tcolor 201 {name Fuchsia                 hex "#ff00ff"}
dict set zesty::tcolor 202 {name {Bright Orange}         hex "#ff5f00"}
dict set zesty::tcolor 203 {name Salmon                  hex "#ff5f5f"}
dict set zesty::tcolor 204 {name {Light Pink2}           hex "#ff5f87"}
dict set zesty::tcolor 205 {name Pink1                   hex "#ff5faf"}
dict set zesty::tcolor 206 {name {Bright Pink3}          hex "#ff5fd7"}
dict set zesty::tcolor 207 {name {Fuchsia Pink2}         hex "#ff5fff"}
dict set zesty::tcolor 208 {name Orange2                 hex "#ff8700"}
dict set zesty::tcolor 209 {name {Light Peach}           hex "#ff875f"}
dict set zesty::tcolor 210 {name {Light Salmon}          hex "#ff8787"}
dict set zesty::tcolor 211 {name {Light Pink3}           hex "#ff87af"}
dict set zesty::tcolor 212 {name Pink2                   hex "#ff87d7"}
dict set zesty::tcolor 213 {name {Orchid Pink}           hex "#ff87ff"}
dict set zesty::tcolor 214 {name Amber                   hex "#ffaf00"}
dict set zesty::tcolor 215 {name Peach2                  hex "#ffaf5f"}
dict set zesty::tcolor 216 {name Apricot                 hex "#ffaf87"}
dict set zesty::tcolor 217 {name {Peach Pink}            hex "#ffafaf"}
dict set zesty::tcolor 218 {name {Pastel Pink}           hex "#ffafd7"}
dict set zesty::tcolor 219 {name {Pink Lavender}         hex "#ffafff"}
dict set zesty::tcolor 220 {name {Gold Yellow}           hex "#ffd700"}
dict set zesty::tcolor 221 {name {Pale Yellow2}          hex "#ffd75f"}
dict set zesty::tcolor 222 {name Beige2                  hex "#ffd787"}
dict set zesty::tcolor 223 {name {Pale Peach}            hex "#ffd7af"}
dict set zesty::tcolor 224 {name {Pale Pink2}            hex "#ffd7d7"}
dict set zesty::tcolor 225 {name {Pale Lavender}         hex "#ffd7ff"}
dict set zesty::tcolor 226 {name {Bright Yellow2}        hex "#ffff00"}
dict set zesty::tcolor 227 {name {Pale Yellow3}          hex "#ffff5f"}
dict set zesty::tcolor 228 {name {Light Yellow2}         hex "#ffff87"}
dict set zesty::tcolor 229 {name Ivory                   hex "#ffffaf"}
dict set zesty::tcolor 230 {name {Rosy White}            hex "#ffffd7"}
dict set zesty::tcolor 231 {name White2                  hex "#ffffff"}

# 3. Grayscale (232-255)
# The 24 shades of gray, from darkest (almost black) to lightest (almost white).

dict set zesty::tcolor 232 {name Gray8    hex "#080808"}
dict set zesty::tcolor 233 {name Gray12   hex "#121212"}
dict set zesty::tcolor 234 {name Gray16   hex "#1c1c1c"}
dict set zesty::tcolor 235 {name Gray20   hex "#262626"}    
dict set zesty::tcolor 236 {name Gray24   hex "#303030"}
dict set zesty::tcolor 237 {name Gray28   hex "#3a3a3a"}
dict set zesty::tcolor 238 {name Gray32   hex "#444444"}
dict set zesty::tcolor 239 {name Gray36   hex "#4e4e4e"}
dict set zesty::tcolor 240 {name Gray40   hex "#585858"}
dict set zesty::tcolor 241 {name Gray44   hex "#626262"}
dict set zesty::tcolor 242 {name Gray48   hex "#6c6c6c"}
dict set zesty::tcolor 243 {name Gray52   hex "#767676"}
dict set zesty::tcolor 244 {name Gray56   hex "#808080"}
dict set zesty::tcolor 245 {name Gray60   hex "#8a8a8a"}
dict set zesty::tcolor 246 {name Gray64   hex "#949494"}
dict set zesty::tcolor 247 {name Gray68   hex "#9e9e9e"}
dict set zesty::tcolor 248 {name Gray72   hex "#a8a8a8"}
dict set zesty::tcolor 249 {name Gray76   hex "#b2b2b2"}
dict set zesty::tcolor 250 {name Gray80   hex "#bcbcbc"}
dict set zesty::tcolor 251 {name Gray84   hex "#c6c6c6"}
dict set zesty::tcolor 252 {name Gray88   hex "#d0d0d0"}
dict set zesty::tcolor 253 {name Gray92   hex "#dadada"}
dict set zesty::tcolor 254 {name Gray96   hex "#e4e4e4"}
dict set zesty::tcolor 255 {name Gray100  hex "#eeeeee"}