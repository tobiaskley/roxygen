#' @include parse-registry.R
#' @import stringr
NULL

register.preref.parsers(parse.value,
                        'name', 
                        'rdname',
                        'aliases',
                        'title',
                        'usage',
                        'references',
                        'concept',
                        'note',
                        'seealso',
                        'example',
                        'examples',
                        'keywords',
                        'return',
                        'author',
                        'section',
                        'format',
                        'source')

register.preref.parsers(parse.name.description,
                        'param',
                        'method')

register.preref.parsers(parse.name,
                        'docType')

register.srcref.parser('<-', function(call, env) {
  assignee <- call[[2]]
  value <- eval(assignee, env)
  
  if (!is.function(value)) {
    list(assignee = as.character(assignee))
  } else {
    list(assignee = as.character(assignee), formals = formals(value))
  }
})


register.srcref.parser('setClass', function(call, env) {
  list(S4class = as.character(call$Class))
})

register.srcref.parser('setGeneric', function(call, env) {
  list(S4generic = as.character(call$name))
})

register.srcref.parser('setMethod', function(call, env) {
  list(
    S4method = as.character(call$f), 
    signature = as.character(call$signature))
})

#' Roclet: make Rd files.
#'
#' This roclet is the workhorse of \pkg{roxygen}, producing the Rd files that
#' document that functions in your package.  
#'
#' This roclet also automatically runs \code{\link[tools]{checkRd}} on all
#' generated Rd files so that you know as early as possible if there's a
#' problem.
#'
#' @section Required tags:
#' 
#' As well as a title and description, extracted from the first sentence and
#' first paragraph respectively, all functions must have the following tags:
#'
#' \describe{
#'
#'  \item{\code{@@param name description}}{Document a parameter.  
#'    Documentation is required for every parameter.}
#'
#'  \item{\code{@@method generic class}}{Required if your function is an S3
#'    method.  This helps R to distinguish between (e.g.) \code{t.test} and 
#'    the \code{t} method for the \code{test} class.}
#'
#'  }
#'
#' @section Optional tags that add extra information:
#'
#' Valid tags for \code{rd_roclet} are:
#' 
#' \describe{
#'
#'  \item{\code{@@aliases space separated aliases}}{Add additional aliases, 
#'    through which the user can find the documentation with \code{?}. 
#'    The topic name is always included in the list of aliases.}
#' 
#'  \item{\code{@@concepts space separated concepts}}{Similar to
#'    \code{@@aliases} but for \code{\link{help.search}}}
#'
#'  \item{\code{@@examples R code...}}{Highly recommended: example code that
#'    demonstrates how to use your function.  Use \\dontrun{} to tag code
#'    that should not automatically be run.}
#' 
#'  \item{\code{@@example path/relative/to/packge/root}}{Instead of including
#'    examples directly in the documentation, you can include them as 
#'    separate files, and use the \code{@@example} tag to insert them into
#'    the documentation.}
#'
#'  \item{\code{@@return}}{Used to document the object returned by the 
#'    function. For lists, use the \code{\\item{name a}{description a}} 
#'    describe each component of the list}
#'
#'  \item{\code{@@author authors...}}{A free text string describing the 
#'    authors of the function.  This is typically only necessary if the
#'    author is not the same as the package author.}
#'
#'  \item{\code{@@references free text reference}}{Pointers to the literature
#'    related to this object.}
#'
#'  \item{\code{@@seealso Text with \\code{\\link{function}}}}{Pointers to
#'    related R objects, and why you might be interested in them.}
#'
#'  \item{\code{@@note contents}}{Create a note section containing additional
#'    information.}
#' 
#'  \item{\code{@@section Name: contents}}{Use to add to an arbitrary section
#'    to the documentation. The name of the section will be the content before
#'    the first colon, and the contents will be everything after the colon.} 
#'
#'  \item{\code{@@keywords keyword1 keyword2 ...}}{Keywords are optional, 
#'    but if present, must be taken from the list in 
#'    \file{file.path(R.home(), "doc/KEYWORDS")}.  Use the \code{internal}
#'    keyword for functions that should not appear in the main function
#'    listing.}
#'
#'  }
#'
#' @template template
#' @section Optional tags that override defaults:
#'
#' These tags all override the default values that roxygen guess from 
#' inspecting the source code.
#' 
#' \describe{
#'
#'  \item{\code{@@rdname filename}}{Overrides the output file name (without
#'    extension). This is useful if your function has a name that is not
#'    a valid filename (e.g. \code{[[<-}), or you want to merge documentation
#'    for multiple function into a single file.}
#' 
#'  \item{\code{@@title Topic title}}{Specify the topic title, which by 
#'    by default is taken from the first sentence of the roxygen block.}
#'
#'  \item{\code{@@usage usage_string}}{Override the default usage string. 
#'    You should not need to use this tag - if you are trying to document
#'    multiple functions in the same topic, use \code{@@rdname}.}
#'
#'  }
#'
#' @section Tags for non-functions:
#'
#' These tags are useful when documenting things that aren't functions, 
#' datasets and packages.
#'
#' \describe{
#'
#'  \item{\code{@@name topicname}}{Override the default topic name, which is
#'    taken by default from the object that is assigned to in the code
#'    immediately following the roxygen block. This tag is useful when
#'    documenting datasets, and other non-function elements.}
#'
#'  \item{\code{@@docType type}}{Type of object being documented. Useful 
#'    values are \code{data} and \code{package}. }
#' 
#'  \item{\code{@@format description}}{A textual description of the format
#'    of the object.}
#'
#'  \item{\code{@@source text}}{The original source of the data.}
#' 
#'}
#' @examples
#' roclet <- rd_roclet()
#' \dontrun{roc_proc(roclet, "example.R")}
#' \dontrun{roc_out(roclet, "example.R", ".")}
#' @export
rd_roclet <- function() {
  new_roclet(list(), "had")
}

#' @S3method roc_process had
roc_process.had <- function(roclet, partita, base_path) {
  # Remove srcrefs with no attached roxygen comments
  partita <- Filter(function(x) length(x) > 1, partita)
  templates <- dir(file.path(base_path, "max-roxygen"), full = TRUE)
  template_hash <- digest(lapply(templates, readLines))
  
  topics <- list()
  for (partitum in partita) {
    key <- c(template_hash, digest(partitum))
    new <- rd_proc_cache$compute(key, roclet_rd_one(partitum, base_path)) 
    if (is.null(new)) next; 
    
    old <- topics[[new$filename]]
    topics[[new$filename]] <- if (is.null(old)) new$rd else merge(old, new$rd)
  }
  topics
}

roclet_rd_one <- function(partitum, base_path) {
  rd <- new_rd_file()
  
  # Add in templates
  partitum <- process_templates(partitum, base_path)
  
  has_rd <- any(names(partitum) %in% c("description", "param", "return",
    "title", "example", "examples", "docType", "name", "rdname", "usage"))
  if (!has_rd) return()
  
  # Figure out topic name
  name <- partitum$name %||% partitum$S4class %||% partitum$S4method %||%
    partitum$S4generic
  # Only use assignee if it's a single element
  if (is.null(name) && length(partitum$assignee) == 1) {
     name <- partitum$assignee
  }
  if (is.null(name)) stop("Missing name")

  # Work out file name and initialise Rd object
  filename <- str_c(partitum$merge %||% partitum$rdname %||% name, ".Rd")
  
  title <- partitum$title %||% first.sentence(partitum$description) %||%
    name

  add_tag(rd, new_tag("name", name))
  add_tag(rd, new_tag("alias", name))
  add_tag(rd, process_had_tag(partitum, 'aliases', function(tag, param) {
      new_tag('alias', words(param))
    }))
  add_tag(rd, new_tag("title", title))
  add_tag(rd, process.usage(partitum))
  add_tag(rd, process.arguments(partitum))
  add_tag(rd, process_had_tag(partitum, 'docType'))
  add_tag(rd, process_had_tag(partitum, 'description', process.description))
  add_tag(rd, process_had_tag(partitum, 'note'))
  add_tag(rd, process_had_tag(partitum, 'author'))
  add_tag(rd, process_had_tag(partitum, 'seealso'))
  add_tag(rd, process_had_tag(partitum, "references"))
  add_tag(rd, process_had_tag(partitum, 'concept'))
  add_tag(rd, process_had_tag(partitum, 'return', function(tag, param) {
      new_tag("value", param)
    }))
  add_tag(rd, process_had_tag(partitum, 'keywords', function(tag, param, all, rd) {
      new_tag("keyword", str_split(str_trim(param), "\\s+")[[1]])
    }))
  add_tag(rd, process_had_tag(partitum, 'section', process.section))
  add_tag(rd, process.examples(partitum, base_path))

  list(rd = rd, filename = filename)
}

#' @S3method roc_output had
#' @importFrom tools checkRd
roc_output.had <- function(roclet, results, base_path) { 
  man <- normalizePath(file.path(base_path, "man"))
  
  contents <- vapply(results, FUN.VALUE = character(1), function(x) {
    rd_out_cache$compute(x, format(x))
  })
  
  write_out <- function(filename, contents) {
    if (the_same(filename, contents)) return()
    
    name <- basename(filename)
    if (!str_detect(name, "^[a-zA-Z][a-zA-Z0-9_.-]*$")) {
      cat("Skipping invalid filename: ", name, "\n")
    } else {
      cat(sprintf('Writing %s\n', name))
      writeLines(contents, filename)    
      checkRd(filename)
    }
    
  }
  the_same <- function(path, new) {
    if (!file.exists(path)) return(FALSE)

    old <- str_c(readLines(path), collapse = "\n")
    return(identical(old, new))
  }
  
  paths <- file.path(man, names(results))
  mapply(write_out, paths, contents)    
}




# Prefer explicit \code{@@usage} to a \code{@@formals} list.
process.usage <- function(partitum) {
  if (!is.null(partitum$usage)) {
    return(new_tag("usage", partitum$usage))
  }
  
  formals <- partitum$formals
  if (length(formals) == 0) return()
  
  args <- usage(formals)
  
  fun_name <- if (!is.null(partitum$method)) {
    rd_tag('method', partitum$method[[1]], partitum$method[[2]])
  } else {
    partitum$assignee
  }

  usage <- str_c(fun_name, "(", args, ")")
  new_tag("usage", usage)
}

# Split the introductory matter into its description followed
# by details (separated by a blank line).
process.description <- function(key, expressions) {
  paragraphs <- strsplit(expressions[[1]], '\n\n', fixed=TRUE)[[1]]
  desc <- paragraphs[[1]]
  details <- do.call(paste, append(paragraphs[-1], list(sep='\n\n')))

  desc_rd <- new_tag("description", str_c(desc, collapse = "\n"))
  
  if (length(details) > 0 && !is.null.string(details)) {
    details_rd <- new_tag("details", details)
  } else {
    details_rd <- NULL
  }
  c(desc_rd, details_rd)
}

process.arguments <- function(partitum) {
  params <- partitum[names(partitum) == "param"]
  if (length(params) == 0) return() 

  desc <- str_trim(sapply(params, "[[", "description"))
  names(desc) <- sapply(params, "[[", "name")
  
  new_tag("arguments", desc)
}

# If \code{@@examples} is provided, use that; otherwise, concatenate
# the files pointed to by each \code{@@example}.
process.examples <- function(partitum, base_path) {
  out <- list()
  if (!is.null(partitum$examples)) {      
    ex <- partitum$examples
    ex <- gsub("([%\\])", "\\\\\\1", ex)
    ex <- gsub("\\\\dont", "\\dont", ex)
    out <- c(out, new_tag("examples", ex))
  } 
  
  paths <- unlist(partitum[names(partitum) == "example"])
  if (length(paths) > 0) {
    paths <- file.path(base_path, str_trim(paths))
    examples <- unlist(lapply(paths, readLines))
    
    out <- c(out, new_tag("examples", examples))
  }
  out
}
process.section <- function(key, value) {
  pieces <- str_split_fixed(value, ":", n = 2)[1, ]
  
  new_tag("section", list(list(name = pieces[1], content = pieces[2])))
}

process_had_tag <- function(partitum, tag, f = new_tag) {
  matches <- partitum[names(partitum) == tag]
  if (length(matches) == 0) return()

  unlist(lapply(matches, function(p) f(tag, p)), recursive = FALSE)
}



# @note Doesn't work recursively!
de.tex <- function(string)
  gsub('\\\\[^{]*\\{([^}]*)(}|)',
       '\\1',
       string,
       perl=TRUE)

# First sentence of a string, defined as first
# period, question mark or newline.
# @param description the string to be first-sentenced
# @return The first sentence
first.sentence <- function(description) {
  description <- de.tex(description)
  r <- regexpr('[^.?\n]*(\\.(?!\\w)|\\?|\n|)',
               description,
               perl=TRUE)
  sentence <- substr(description, r, attr(r, 'match.length'))
  if (length(sentence) == 0 || is.null.string(sentence))
    NULL
  else {
    chars <- nchar(sentence)
    last.char <- substr(sentence, chars, chars)
    if (last.char == '.' || last.char == '?')
      sentence
    else
      paste(str_trim(sentence), '...', sep='')
  }
}

# warning("All roxygen elements must have name: ",
#   partitum$srcref$filename, ":", partitum$srcref$lloc[1], ":",
#   partitum$srcref$lloc[2], call. = FALSE)