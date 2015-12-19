type Token
  dicts::Tuple{Dict, Dict, Dict}
  word::UTF8String
  chars::Vector{Char}
  catid::Int
end

function readlist(path)
  dict = Dict()
  lines = open(readlines, path)
  for l in lines
    get!(dict, chomp(l), length(dict)+1)
  end
  dict
end

function readCoNLL(path, dicts)
  worddict, chardict, catdict = dicts
  data = open(readlines, path)
  doc = Vector{Token}[]
  sent = Token[]
  for line in data
    line = chomp(line)
    if length(line) == 0
      push!(doc, sent)
      sent = Token[]
    else
      items = split(chomp(line), '\t')
      word = replace(items[2], r"[0-9]", '0') |> UTF8String
      chars = convert(Vector{Char}, word)
      cat = items[5]
      catid = get!(catdict, cat, length(catdict) + 1)
      tok = Token(dicts, lowercase(word), chars, catid)
      push!(sent, tok)
    end
  end
  println("# words: $(length(worddict))")
  println("# chars: $(length(chardict))")
  println("# cats: $(length(catdict))")
  doc
end

function eval(golds::Vector{Token}, preds::Vector{Int})
  @assert length(golds) == length(preds)
  correct = 0
  total = 0
  for i = 1:length(golds)
    if golds[i].catid == preds[i]
      correct += 1
    end
    total += 1
  end
  correct / total
end
