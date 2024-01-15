using DataFrames, Random, OpenAI, GMT, JSON3

secretkey = "#####"
model = "gpt-3.5-turbo"
file_path = "/Users/jacobappleton/Downloads/Physics Questions.txt"

function Test_Question_Extract(file_path::AbstractString)
 
    test_text = read(file_path, String)

    text = split(test_text, "\n")
    texta = filter((i) -> i != "\r", text)

    function take_only_mc_Qs(vector)
        start_keyword = "Part"
        end_keyword = "multiple choice"
    
        start_index = findfirst(x -> contains(x, start_keyword) && contains(x, end_keyword), vector)
    
        if start_index === nothing
         return nothing  # Start keyword not found
        end
    
        end_index = find_end_index(vector, start_index+1, start_keyword)
    
        if end_index === nothing
            return nothing  # End keyword not found
     end
    
        return vector[start_index+1:end_index-1]
    end
    function find_end_index(vector, start_index, end_keyword)
        for i in start_index:length(vector)
         if contains(vector[i], end_keyword)
                return i
            end
        end
        return nothing
    end

    function process_questions(questions)
        result = Vector{String}()
        current_question = ""

        for line in questions
            if occursin(r"^\d+\.\s+true or false", line)
            # Skip true/false line and treat subsequent lines as options
                push!(result, strip(line))
            elseif occursin(r"^\d+\.", line)
            # Process multiple choice questions
                if !isempty(current_question)
                    push!(result, current_question)
                end
             current_question = strip(line)
            else
            # Combine lines for the same multiple choice question or true/false options
                current_question *= " " * strip(line)
            end
        end

    # Add the last question
        if !isempty(current_question)
            push!(result, current_question)
        end

        return result
    end

    function split_elements(vec)
        result = Vector{String}()
        for element in vec
        # Check if the element contains the words "true or false"
         if occursin("true or false", element)
            # Split based on a single integer preceded by a space and followed by a period
                parts = split(element, r" (\d+)\.")
            
            # Remove empty strings from the split result
                parts = filter(x -> x ≠ "", parts)
            
            # Append the parts to the result
                append!(result, parts)
            else
            # If the element does not contain "true or false", keep it as is
             push!(result, element)
            end
        end

     # Remove elements containing "true or false" from the result
         result = filter(x -> !occursin("true or false", x), result)

      # Add "(1KM)" to the end of every element that begins with a number, and "(1KF)" to others
        for i in 1:length(result)
            if isdigit(first(result[i]))
                result[i] *= " (1KM)"
            else
                result[i] *= " (1KF)"
         end
     end

    # Remove the first 3 characters if it begins with a number
        result = [length(x) > 3 && isdigit(first(x)) ? x[4:end] : x for x in result]

        return result
    end

    mc1 = take_only_mc_Qs(texta)
    mc2 = process_questions(mc1)
    mc3 = split_elements(mc2)

    function removemc(vector)
        new_vector = Vector{String}()
        i = 1
        while i <= length(vector)
            if contains(vector[i], "Part") && contains(vector[i], "false")
                # Skip the current element and remove subsequent elements until the next "Part"
                i += 1
                while i <= length(vector) && !contains(vector[i], "Part")
                    i += 1
                end
            else
                # Keep the current element
                push!(new_vector, vector[i])
                i += 1
            end
        end
        return new_vector
    end

    function combinequestionlines(vector) ### needs to add element on new line in string
        processed_vector = Vector{String}()
        current_line = ""

        for line in vector
            if occursin(r"^\s*\d+\.", line)
                # Line starts with a number and a dot, keep it as is
                push!(processed_vector, current_line)
                current_line = line
            else
                # Line does not start with a number and a dot, append it to the current line on a new line
                current_line *= "\n$line"
            end
        end

        # Add the last processed line
        push!(processed_vector, current_line)

        # Filter out empty strings
        processed_vector = filter(x -> x != "", processed_vector)

        return processed_vector
    end

    textb = removemc(texta)
    textc = filter((i) -> !(contains(i, "Part")), textb)
    textd = filter((i) -> !(contains(i, "test")), textc)
    texte = combinequestionlines(textd)
    textf = append!(texte, mc3)

    function extractInformation(original_vector)
        numbers = []
        letters1 = []
        letters2 = []
        modified_elements = []

        letter1_mapping = Dict("K" => "Knowledge/Understanding", "T" => "Thinking/Inquiry",
                            "A" => "Application", "C" => "Communication")

        letter2_mapping = Dict("F" => "True/False", "M" => "Multiple Choice", "G" => "GRESS")

        for element in original_vector
            # Extract the number and letters using a regular expression
            match_result = match(r"\((\d+)([A-Z])([A-Z]?)\)", element)

            if match_result !== nothing
                number = parse(Int, match_result.captures[1])
                letter1 = haskey(letter1_mapping, match_result.captures[2]) ? letter1_mapping[match_result.captures[2]] : match_result.captures[2]

                # Check if the first letter is "C" and there is no second letter
                if letter1 == "Communication" && isempty(match_result.captures[3])
                    letter2 = "Short Answer"
                else
                    letter2 = haskey(letter2_mapping, isempty(match_result.captures[3]) ? "G" : match_result.captures[3]) ? letter2_mapping[isempty(match_result.captures[3]) ? "G" : match_result.captures[3]] : match_result.captures[3]
                end

                # Extract the modified element without removing the first three characters
                modified_element = strip(replace(element, r"\(\d+[A-Z][A-Z]?\)" => ""))

                # Remove the first 3 characters if it begins with a number
                modified_element = length(modified_element) > 3 && isdigit(first(modified_element)) ? modified_element[4:end] : modified_element

                # Add the extracted information to respective vectors
                push!(numbers, number)
                push!(letters1, letter1)
                push!(letters2, letter2)
                push!(modified_elements, modified_element)
            else
                println("Warning: Unable to extract number and letters from element: $element")
            end
        end

        return numbers, letters1, letters2, modified_elements
    end

    numbers, letters1, letters2, modified_elements = extractInformation(textf)

    df = DataFrame(Question = modified_elements, Value = numbers, Category = letters1, Answer_Format = letters2, )

    return df
    
end

function coursecodeify(course_to_add)
    if grade_level == 12
        coursenum = "4"
    elseif grade_level == 11
        coursenum = "3"
    elseif grade_level == 10
        coursenum = "2"
    elseif grade_level == 9
        coursenum = "1"
    else
        coursenum = "$grade_level"
    end

    if course_to_add == "Physics"
        coursecode = "SPH"
    elseif course_to_add == "Chemistry"
        coursecode = "SCH" 
    elseif course_to_add == "Biology"
        coursecode = "SBI" 
    else
        "SCI"
    end

    course_mapping = Dict(course_to_add => coursecode*coursenum*"U1" )
    return coursecode*coursenum*"U1"
end

function access_questions(df, input_value, input_category, input_answer_format)
    # Mapping for letter1
    letter1_mapping = Dict("K" => "Knowledge/Understanding", "T" => "Thinking/Inquiry",
                            "A" => "Application", "C" => "Communication")

    # Mapping for letter2
    letter2_mapping = Dict("F" => "True/False", "M" => "Multiple Choice", "G" => "GRESS")

    # Use mappings to convert single-letter inputs to full categories
    mapped_category = get(letter1_mapping, input_category, input_category)
    mapped_answer_format = get(letter2_mapping, input_answer_format, input_answer_format)

    # Filter DataFrame based on mapped input values
    filtered_df = filter(row -> row.Value == input_value && row.Category == mapped_category && row.Answer_Format == mapped_answer_format, df)

    # Extract questions from the filtered DataFrame
    matching_questions = filtered_df.Question

    return matching_questions
end

function generate_chatgpt_prompt(df, input_value, input_category, input_answer_format)
    # Mapping for letter1
    letter1_mapping = Dict("K" => "Knowledge/Understanding", "T" => "Thinking/Inquiry",
                            "A" => "Application", "C" => "Communication")

    # Mapping for letter2
    letter2_mapping = Dict("F" => "True/False", "M" => "Multiple Choice", "G" => "GRESS")

    # Use mappings to convert single-letter inputs to full categories
    mapped_category = get(letter1_mapping, input_category, input_category)
    mapped_answer_format = get(letter2_mapping, input_answer_format, input_answer_format)

    # Determine the appropriate answer format based on category
    if mapped_category == "Communication"
        mapped_answer_format = "Short Answer"
    end

    if mapped_answer_format == "GRnnESS"
        mapped_answer_format = "Question that requires calculations in a given, required, equations, solve, statement, format"
    end

    # Filter DataFrame based on mapped input values
    filtered_df = filter(row -> row.Value == input_value && row.Category == mapped_category && row.Answer_Format == mapped_answer_format, df)

    # Extract matching questions from the filtered DataFrame
    matching_questions = filtered_df.Question

    # Construct the ChatGPT prompt with examples
    prompt = """
    I'm a teacher, I need you to generate a single new $mapped_answer_format test question for the $mapped_course course $unit_to_add unit in the Ontario Curriculum. Of the categories of marks it should evaluate for (Thinking/Inquiry, Communication, Knowledge/Understanding, and Application), this question should evaluate for $mapped_category, and should be worth $input_value mark(s). 

    Here are succesful example questions already made by me for all the same paramaters to base it on:
    """

    # Add matching questions as examples
    for (i, question) in enumerate(matching_questions)
        prompt *= "    $i. $question\n"
    end

    # Modify the end part based on answer format
    if mapped_answer_format == "True/False"
        prompt *= """
        The output should be in the form 6 items only on sepperate lines. The first item is "AI", the second item is the question output alone, the third item contains the correct answer (either "True" or "False"), the fourth item is $input_value, the 5th item is the word $mapped_category, and the sixth item is the word $mapped_answer_format.
        """
    elseif mapped_answer_format == "Multiple Choice"
        prompt *= """
        The output should be in the form 6 items only on sepperate lines. The first item is "AI", the second item is the question output with the possible answers (A. B. C. D.) on the same line comma sepperated, the third item contains the correct answer's letter (an uppercase letter followed by a .), the fourth item is $input_value , the 5th item is the word $mapped_category, and the sixth item is the word $mapped_answer_format.
        """
    elseif mapped_category == "Communication"
        prompt *= """
        The output should be in the form 6 items only on sepperate lines. The first item is "AI", the second item is the question output, the third item is a correct answer example, the fourth item is $input_value, the 5th item is the word $mapped_category, and the sixth item is the word $mapped_answer_format.
        """
    elseif mapped_answer_format == "GRESS"
        prompt *= """
        The output should be in the form 6 items only on sepperate lines. The first item is "AI", the second item is the question output, the third item is the correct answer alone, the fourth item is $input_value, the 5th item is the word $mapped_category, and the sixth item is the word $mapped_answer_format.
        """
    else
        prompt *= """
        The output should be in the form 6 items only on sepperate lines. The first column as contains the word "AI", the second column the question output, the third column containing a correct answer example, the fourth column containing an integer alone that is " $input_value ", the 5th column containing " $mapped_category ", and the sixth columm containing " $mapped_answer_format ". The array should be output on one line.
        """
    end

    return prompt
end

function map_made_by(made_by)
    made_by_mapping = Dict("T" => "Teacher", "A" => "AI")
    if made_by == "T" || made_by == "A"
        madep = get(made_by_mapping, made_by, made_by)
    
    else
        madep = nothing
    end
    return madep
end

function map_value(value)
    value_mapping = Dict("1" => "1", "2" => "2", "3" => "3", "4" => "4", "5" => "5", "6" => "6")
    return get(value_mapping, string(value), nothing)
end

function map_category(category)
    category_mapping = Dict("K" => "Knowledge/Understanding", "T" => "Thinking/Inquiry",
                            "A" => "Application", "C" => "Communication")
    return get(category_mapping, category, nothing)
end

function map_answer_format(answer_format)
    answer_format_mapping = Dict("S" => "Short Answer", "A" => "Multiple Answer", "M" => "Multiple Choice",
                                 "F" => "True/False", "G" => "GRESS")
    return get(answer_format_mapping, answer_format, nothing)
end

function custom_filter(df; made_by, value, category, answer_format)
    made_by = map_made_by(made_by)
    value = map_value(value)
    category = map_category(category)
    answer_format = map_answer_format(answer_format)

    if made_by != nothing
        equals_alicem(name::String) = name == made_by
        en = filter(:Made_By => equals_alicem, df)
        df = en
    else
        df = df
    end

    if value != nothing
        equals_alicev(name::Any) = name == value
        equals_alicex(name::Any) = name == parse(Int, value)
        ev = filter(:Value => equals_alicev, df)
        ev2 = filter(:Value => equals_alicex, df)
        df = append!(ev, ev2)
    else
        df = df
    end

    if category != nothing
        equals_alicec(name::Any) = name == category
        dc = filter(:Category => equals_alicec, df)
        df = dc
    else
        df = df
    end

    if answer_format != nothing
        equals_alicez(name::Any) = name == answer_format
        da = filter(:Answer_Format => equals_alicez, df)
        df = da
    else
        df = df
    end
    return df
end

function get_input(prompt)
    println(prompt)
    answer = readline()
    return answer == "n" ? nothing : answer
end

function generate_additional_questions(df, numq, value, category, answer_format)
    for i in 1:numq
        chatgpt_prompt = generate_chatgpt_prompt(df, value, category, answer_format)
        chatp = generate_chat_with_retry(secretkey, model, chatgpt_prompt)
        gpt_output = chatp[2]
        print(gpt_output)
        println("Is this question ok? (y/n)")
        valiinput = readline()

        if valiinput == "n"
            println("next output")
        else
        push!(filtered_df, chatp)
        end
    end
    return filtered_df
end

function cliapp(df)
    logoprint()
    inter = println("Alpha V. 1.0.0")

    println("Who is this? (User to save data to)")
    readline()
    num_columns = 1
    println("What course is this? (Course category to save data to)")
    course_to_add = readline()
    println("Which grade level? (Grade category to access)")
    grade_level = readline()
    println("What unit is this?")
    unit_to_add = readline()

    while true
        interinput = readline()
        if interinput == "Train"
            println("Enter paths of images or files (comma seperated) to upload")
            readline()
            println("Running Tesseract...")
            path = "/Users/jacobappleton/Downloads/Physics Questions.txt"
            sleep((rand(1)*3)[1])
            println("Segmented training data:")
            df = Test_Question_Extract(path)
            answer = "blank"
            df = insertcols!(df, 2, :Answer => answer)
            madeby = "Teacher"
            df = insertcols!(df, 1, :Made_By => madeby)
            vscodedisplay(df)
            interinput = readline()

        elseif interinput == "AI"
            println("Number of 'Question' Required")
            numq = readline()
            println("Category of Question, (A -> Application, K -> Knowledge/Understanding, C -> Communication, T -> Thinking/Inquiry)")
            catq = readline()
            println("Answer Format (F -> True/False, M -> Multiple Choice, G -> GRESS or GRASS, S -> Short Answer)")
            formq = readline()
            println("Mark Value of 'Question'")
            valq = readline()
            input_value = valq
            input_category = catq
            input_answer_format = formq

            if input_category == "K" 
                if input_answer_format == "F"
                    temperature = 0.5
                else
                    temperature = 0.5
                end
            elseif input_category == "T"
                temperature = 0.3
            elseif input_category == "C"
                temperature = 1.5
            else
                temperature = 0.7
            end

            for i in 1:parse(Int, numq)
                chatgpt_prompt = generate_chatgpt_prompt(df, input_value, input_category, input_answer_format)
                chatp = generate_chat_with_retry(secretkey, model, chatgpt_prompt)
                prompt_result = chatp[2]
                println(prompt_result)
                println("Is this question ok? (y/n)")
                valiinput = readline()
                if valiinput == "y"
                    df = push!(df, chatp)
                    vscodedisplay(df)
                else valiinput == "n"
                    println("next output")
                end
            end

            interinput = readline()
        elseif interinput == "Test"
            testdf = DataFrame()
            println("Test generator, answer the following prompts to add types of questions to the test")
            while true
                made_by = get_input("Enter preference for who generated the question, (A -> AI, T -> Teacher) or 'n' to ignore:")
                category = get_input("Enter a mark value of the question or 'n' to ignore:")
                value = get_input("Enter the category of the question (A -> Application, K -> Knowledge/Understanding, C -> Communication, T -> Thinking/Inquiry) or 'n' to ignore:")
                answer_format = get_input("Enter the answering format of the question (F -> True/False, M -> Multiple Choice, G -> GRESS or GRASS, S -> Short Answer ) or 'n' to ignore:")
                in5 = get_input("Enter the number of this question type to add to the test")
            
                filtered_df = custom_filter(df; made_by, value, category, answer_format)
                
                if in5 != nothing
                    num_rows = parse(Int, in5)
                    leftover = string(num_rows - nrow(filtered_df))
                    if num_rows > nrow(filtered_df)
                        println("AI generating the $leftover leftover questions that are not in the dataset")
                        generated_df = generate_additional_questions(df, num_rows - nrow(filtered_df), value, category, answer_format)
                        testdf = filtered_df
                    else
                        filtered_df = filtered_df[shuffle(1:nrow(filtered_df))[1:min(num_rows, nrow(filtered_df))], :]
                        testdf = append!(testdf, filtered_df)
                    end
                end
            
                another_question = get_input("Another question? (y/n):")
                if isnothing(another_question) || lowercase(another_question) == "n"
                    for i in 1:num_columns
                        col_name = "Course"
                        testdf[!, col_name] .= course_to_add
                    end
                    
                    for i in 1:num_columns
                        col_name = "Unit"
                        testdf[!, col_name] .= unit_to_add
                    end
                    println("Final DataFrame:")
                    return testdf
                    vscodedisplay(testdf)
                    break
                end
            end

        elseif interinput == "end"
            for i in 1:num_columns
                col_name = "Course"
                df[!, col_name] .= course_to_add
            end
            
            for i in 1:num_columns
                col_name = "Unit"
                df[!, col_name] .= unit_to_add
            end
            vscodedisplay(df)
            println("Saved!")
            return df
        else
            println("Failed")
            interinput = readline()
            return df
        end
    end
    return df
end

function parse_openai_response(chat::OpenAIResponse)
    content = chat.response[:choices][begin][:message][:content]
    # Remove leading and trailing whitespaces and the enclosing quotes
    content_array = split(content, "\n")
    return content_array
end

function generate_chat_with_retry(secretkey, model, chatgpt_prompt)
    while true
        top_p = 0.3
        chat = create_chat(secretkey, model, [Dict("role" => "system", "content" => chatgpt_prompt)]; top_p, temperature)
        gpt_output = parse_openai_response(chat)

        if length(gpt_output) == 6
            return gpt_output
        else
            println("Invalid Format. Remaking...") ###Remove
        end
    end
end

function generate_test_pdf(df::DataFrame, output_filename::AbstractString) ###
    # Create an array to store LaTeX code for each question
    latex_code = String[]

    # Separate questions based on type
    mc_questions = filter(row -> row[:Answer_Format] == "Multiple Choice", df)
    tf_questions = filter(row -> row[:Answer_Format] == "True/False", df)
    gress_questions = filter(row -> row[:Answer_Format] == "GRESS", df)
    sa_questions = filter(row -> row[:Answer_Format] == "Short Answer", df)

    # Function to format options for multiple-choice questions
    function format_options(options)
        formatted_options = join(") ", options)
        return "($formatted_options)"
    end

    rowspl = 0
    hcat(mc_questions, DataFrame(reduce(vcat, permutedims.(split.((string.(mc_questions.Question)), "1."))), [:Questions, :Options]))
    # Add multiple-choice questions to LaTeX code
    for row in eachrow(mc_questions)
        question_text = row[:Question]
        options =  hcat(mc_questions, DataFrame(reduce(vcat, permutedims.(split.((string.(mc_questions.Question)), "1."))), [:Questions, :Options]))[:, 7]
        formatted_options = format_options(options)
        push!(latex_code, "\\item $question_text $formatted_options")
    end

    # Add true/false questions to LaTeX code
    for row in eachrow(tf_questions)
        question_text = row[:Question]
        push!(latex_code, "\\item $question_text \\hspace{1cm} T \\hspace{1cm} F")
    end

    # Add GRESS questions to LaTeX code
    for row in eachrow(gress_questions)
        question_text = row[:Question]
        push!(latex_code, "\\item $question_text \\newline \\vspace{4cm}")
    end

    # Combine all questions into a LaTeX document
    latex_document = """
        \\documentclass{article}
        \\begin{document}
        \\begin{enumerate}
        $(join(latex_code, "\n"))
        \\end{enumerate}
        \\end{document}
    """

    # Save LaTeX document to a .tex file
    tex_filename = "$output_filename.tex"
    open(tex_filename, "w") do file
        write(file, latex_document)
    end

    # Use Plots to compile LaTeX document and generate PDF
    plot(tex_filename, pdf_output=true, pdf_filename="$output_filename.pdf")

    println("PDF generated successfully: $output_filename.pdf")
end

function logoprint()
    println("""
    8888888888 888 d8b                                 888                           
    888        888 Y8P                                 888                           
    888        888                                     888                           
    8888888    888 888 88888b.  88888b.   .d88b.   .d88888                           
    888        888 888 888 "88b 888 "88b d8P  Y8b d88" 888                           
    888        888 888 888  888 888  888 88888888 888  888                           
    888        888 888 888 d88P 888 d88P Y8b.     Y88b 888                           
    88d8888b.  888 888 88888P"  88888P"   "Y8888   "Y88888                           
    d88P  Y88b 888     888      888                                                  
    888    888 888     888      888                                                  
    888        888  8888b.  .d8888b  .d8888b  888d888 .d88b.   .d88b.  88888b.d88b.  
    888        888     "88b 88K      88K      888P"  d88""88b d88""88b 888 "888 "88b 
    888    888 888 .d888888 "Y8888b. "Y8888b. 888    888  888 888  888 888  888  888 
    Y88b  d88P 888 888  888      X88      X88 888    Y88..88P Y88..88P 888  888  888 
     "Y8888d888888888888888  88888P'  88888P' 888     "Y88P"   "Y88P"  888  888  888 
          d88888   888                                                               
         d88P888   888                                                               
        d88P 888   888                                                               
       d88P  888   888                                                               
      d88P   888   888                                                               
     d8888888888   888   d8b                                                         
    d88P     888 8888888 Y8P  
    """)
end

df = cliapp(df)
