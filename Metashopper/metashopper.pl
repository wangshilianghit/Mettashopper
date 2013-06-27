#!/usr/local/bin/perl -w
################################################################
#   Shiliang Wang and Guannan Ren
#   Email: wangshiliang@jhu.edu, gren3@jhu.edu
#   Information Retrieval Final Project
#   Spring 2013
#################################################################

###############################################################
##  metashopper.pl
##
##  Usage:   perl metashopper.pl configuration.txt log.txt result.txt
##
##  Note:  the configuration.txt is used to initialize the datastructure %CFG
##         the log.txt used to check the errors and debug the program
##         the result.txt used to output the final result after ranking.
##
##  The function &main_loop below gives the menu for the system.
##
##  The user should select the category first, then input the query,
##  and the ranking method.
################################################################

use Carp;
use FileHandle;
use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request::Common qw(GET);
use HTTP::Request::Common qw(POST);

# %CFG
#   A hash of hash data structure. The data structure is constructed with the configuration files. 
#   It includes all the information about the category, the url list for each category and the
#   regular expression, attributes to extract form the html for each url. 
my %CFG = ();

# %stoplist_hash
#   common list of uninteresting words which are not so important
#   to any query.
#
#   Note: this is an associative array to provide fast lookups
#         of these boring words
my %stoplist_hash = {};

my $ua = undef;
my $classification = undef;



&main_loop;

##########################################################
## MAIN_LOOP
##
## Parameters: currently no explicit parameters.
##             performance dictated by user imput.
## 
## Initializes the %CFG datastructure using the configuration files,
## Initialize the lwp, and initialize the %common words using the commonword file
##
## Then offers
## a menu and switch to appropriate functions in an
## endless loop.
## 
##########################################################

sub main_loop {
    &initialize_configuration;
    &initialize_lwp;
    &initialize_common_words;
    
    my $log_file = shift (@ARGV);
    my $result_file = shift (@ARGV);
    
    if ((!defined ($log_file)) || (!defined ($result_file))) {
        print STDERR "You must specify a log file and a result file\n";
        print STDERR " perl ./metashopper.pl configuration.txt log.txt result.txt\n";
        exit (1);
    }
    
    while(1){
        print "\n\nPlease select a category;\n";
        print " Options:\n";
        my $index = 1;
        foreach my $key (keys %CFG) {
            print " " . $index . " = " . $key . "\n";
            ++$index;
        }
        print " " . $index . " = Quit\n";
        my $option = <STDIN>;
        my $classification = undef;
        chomp $option;
        
        exit 0 if $option == $index;
        
        open LOG, ">$log_file";
        open RESULT, ">$result_file";
        $classification = (keys %CFG)[$option-1];
        print "Please input the query;\n";
        my $query = <STDIN>;
        chomp($query);
        $query = lc($query);
        
        my %query_vector = ();
        my @query_array = split(' ', $query);
        
        print LOG "query vector size is " . scalar @query_array . "\n"; 
        for my $element ( @query_array ){
            if (! exists $stoplist_hash{ $element }) {
                $query_vector{ $element } += 2;
            }
            else{
                $query_vector{ $element } += 1;
            }
        }
        
        print " Please select the ranking method:\n";
        print " Options:\n";
        print " 1 = Ranked by price\n";
        print " 2 = Ranked by rating\n";
        print " 3 = Ranked by relevance\n";
        print " 4 = Overall ranking\n";
        
        my $method = <STDIN>;
        chomp $method;
        
        my @result;
        
        # open LOG, ">$log_file";
        # open RESULT, ">$result_file";
        
        while (my ($key, $value) = each($CFG{$classification})){
            my $request_method = undef;
            
            if ($key ne "attribute"){
                #we need to process the url first, substitute the $1 with the query
                my $url = $key;
                my $post_attribute = undef;
                
                #we need to determine the request method based on whether the url contains '__1' or not
                if (index($url, '__1') != -1) {
                    $request_method = 'GET';
                    $url =~ s/__1/$query/g;
                }
                else{
                    my @url_array = split('@', $url);
                    $url = $url_array[0];
                    $request_method = 'POST';
                }
                
                print LOG "url: " . $url . "\n";
                print "url: " . $url . "\n";
                
                #get the regex and the attribute of that url
                my $regex = undef;
                my %attribute = ();
                
                while(my ($key, $value) = each(%$value)){
                    if ($key eq "regex"){
                        $regex = $value;
                        print LOG "regex: " . $regex . "\n"
                    }
                    else{
                        while(my ($key, $value) = each(%$value)){
                            $attribute{ $key } = $value;
                        }
                    }
                }
                
                #request the url based on the request method
                my $req = undef;
                if ($request_method eq 'POST'){
                    if (index($url, "ebay") != -1){
                        if ($classification eq 'Clothing'){
                            $req = POST $
                            url, [ _nkw=>$query, _sacat=>11450];
                        }
                        elsif ($classification eq 'Office'){
                            $req = POST $url, [ _nkw=>$query, _sacat=>12576];
                        }
                        elsif ($classification eq 'Books'){
                            $req = POST $url, [ _nkw=>$query, _sacat=>267];
                        }
                        elsif ($classification eq 'Computer'){
                            $req = POST $url, [ _nkw=>$query, _sacat=>58058];
                        }
                        elsif ($classification eq 'All categories'){
                            $req = POST $url, [ _nkw=>$query, _sacat=>58058];
                        }
                    }
                    elsif (index($url, "kmart") != -1){
                        if ($classification eq 'Clothing'){
                            $req = POST $url, [ keyword=>$query, autoRedirect=>'false',catPrediction=>'false',keywordSearch=>'false',vName=>'Clothing'];
                        }
                        elsif ($classification eq 'Electronics'){
                            $req = POST $url, [ keyword=>$query, autoRedirect=>'false',catPrediction=>'false',keywordSearch=>'false'];
                        }
                        elsif ($classification eq 'All categories'){
                            $req = POST $url, [ keyword=>$query, autoRedirect=>'false',catPrediction=>'false',keywordSearch=>'false'];
                        }
                    }
                    elsif (index($url, "sears") != -1){
                        $req = POST $url, [ keyword=>$query,autoRedirect=>'false',catPrediction=>'false',keywordSearch=>'false'];
                    }
                }
                else{
                    $req = GET $url;
                }
                
                my $res = $ua->request($req);
                my $content = undef;
                #check the response
                if ($res->is_success) {
                    $content = $res->content;
                    if (length($content) < 100){
                        $content = "";
                    }
                } 
                else {
                    $content = "";
                    print $res->status_line . "\n";
                }
                
                #check the content:
                if (index($url, "walmart") != -1){
                    if ($classification ne 'Books'){
                        if ($content =~ m/<div class="BookAuthor">/){
                            $content = "";
                        }
                    }
                }
                if (index($url, "amazon") != -1){
                    if ($classification ne 'Books'){
                        if ($content =~ m/<div class="Kindle Edition">/){
                            $content = "";
                        }
                    }
                }

                my $num = 0;
                print LOG "extract the content now\n";
                #The maximum number for each ventors I set is 10， this can be changed
                my $number = 10;
                while ($content =~ m/$regex/g){
                    if ($number <= 0){
                        last;
                    }
                    --$number;
                    my %single_result = ();
                    my $save = 0;
                    
                    ++$num;
                    if (index($url, "abebooks") != -1){
                        my $link = $1;
                        my $title = $2;
                        my $author = $3;
                        my $bookseller = $4;
                        my $rating = $5;
                        my $quantity = $6;
                        my $price = $7;
                        $link = "http://www.abebooks.com" . $link;
                        #we should get the number of rating. The rating of abebooks is from 0 to 5
                        $rating = substr($rating, 0, 1);
                        #we should to remove all the unrellated characters of price
                        $price =~ s/[A-Z_a-z \$,]+//g;
                        
                        if ($title ne "" and $author ne "" and $price ne ""){
                            $save = 1;
                            $single_result{ 'link' } = $link;
                            $single_result{ 'title' } = $title;
                            $single_result{ 'author' } = $author;
                            $single_result{ 'bookseller' } = $bookseller;
                            $single_result{ 'rating' } = $rating;
                            $single_result{ 'quantity' } = $quantity;
                            $single_result{ 'price' } = $price;
                        }
                    }
                    
                    elsif (index($url, "amazon") != -1){
                        if ($classification eq 'Books'){
                            my $link = $1;
                            my $title = $2;
                            my $author = $3;
                            my $rating = $4;
                            my $price = $5;
                            my @rating_array = split(' ', $rating);
                            $rating = $rating_array[0];
                            $title =~ s/[>]+//g;
                            #we should to remove all the unrellated characters of price
                            $price =~ s/[A-Z_a-z \$,]+//g;
                            
                            if ($title ne "" and $author ne "" and $price ne "" and $price != 0.00){
                                $save = 1;
                                $single_result{ 'link' } = $link;
                                $single_result{ 'title' } = $title;
                                $single_result{ 'author' } = $author;
                                $single_result{ 'rating' } = $rating;
                                $single_result{ 'price' } = $price;
                            }
                        }
                        else{
                            my $link = $1;
                            my $title = $2;
                            my $price = $3;
                            my $rating = $4;
                            my @rating_array = split(' ', $rating);
                            $rating = $rating_array[0];
                            $price =~ s/[A-Z_a-z \$,]+//g;
                            
                            if ($title ne "" and $price ne ""){
                                $save = 1;
                                $single_result{ 'link' } = $link;
                                $single_result{ 'title' } = $title;
                                $single_result{ 'price' } = $price;
                                $single_result{ 'rating' } = $rating;
                            }
                        }
                    }
                    
                    elsif (index($url, "barnesandnoble") != -1){
                        my $title = $1;
                        my $author = $2;
                        my $product_link = $3;
                        my $price = $4;
                        $title =~ s/["]+//g;
                        $price =~ s/[A-Z_a-z \$,]+//g;
                        
                        my $product_page = GET $product_link;
                        my $page_content = $ua->request($product_page);
                        my $desc_content = undef;
                        if ($page_content->is_success) {
                            $desc_content = $page_content->content;
                        } 
                        else {
                            print $page_content->status_line . "\n";
                        }
                        my $description = "";
                        ($description) = $desc_content =~ m/<meta name="description" content="([^"]*)"\/>/;
                        
                        if ($title ne "" and $price ne "" and $price != 0.00){
                            $save = 1;
                            $single_result{ 'link' } = $product_link;
                            $single_result{ 'title' } = $title;
                            $single_result{ 'author' } = $author;
                            $single_result{ 'price' } = $price;
                            $single_result{ 'description' } = $description;
                        }
                    }
                    
                    elsif (index($url, "ebay") != -1){
                        my $link = $1;
                        my $title = $2;
                        my $price = $3;
                        $price = trim($price);
                        $price =~ s/[A-Z_a-z \$,">=]+//g;
                        
                        my $product_page = GET $link;
                        my $page_content = $ua->request($product_page);
                        my $desc_content = undef;
                        if ($page_content->is_success) {
                            $desc_content = $page_content->content;
                        } 
                        else {
                            print $page_content->status_line . "\n";
                        }
                        my $description = "";
                        ($description) = $desc_content =~ m/meta\sname\=\"description.+?content\=\"([^\"]*)/sm;
                        
                        if ($title ne "" and $price ne ""){
                            $save = 1;
                            $single_result{ 'link' } = $link;
                            $single_result{ 'title' } = $title;
                            $single_result{ 'price' } = $price;
                        }
                    }
                        
                    elsif (index($url, "kmart") != -1){
                        my $link = $1;
                        my $title = $2;
                        my $price = $3;
                        $price = trim($price);
                        $price =~ s/[A-Z_a-z \$,">]+//g;
                        $link = "http://www.kmart.com". $link;
                        
                        if ($title ne "" and $price ne ""){
                            $save = 1;
                            $single_result{ 'link' } = $link;
                            $single_result{ 'title' } = $title;
                            $single_result{ 'price' } = $price;
                        }
                    }
                    
                    elsif (index($url, "pcrush") != -1){
                        my $link = $1;
                        my $title = $2;
                        my $price = $3;
                        $link = "http://www.pcrush.com". $link;
                        $price =~ s/[A-Z_a-z \$,]+//g;
                        
                        if ($title ne "" and $price ne ""){
                            $save = 1;
                            $single_result{ 'link' } = $link;
                            $single_result{ 'title' } = $title;
                            $single_result{ 'price' } = $price;
                        }
                    }
                    
                    elsif (index($url, "sears") != -1){
                        my $link = $1;
                        my $title = $2;
                        my $price = $3;
                        $price = trim($price);
                        $price =~ s/[A-Z_a-z \$,]+//g;
                        $link = "http://www.sears.com" . $link;
                        
                        if ($title ne "" and $price ne ""){
                            $save = 1;
                            $single_result{ 'link' } = $link;
                            $single_result{ 'title' } = $title;
                            $single_result{ 'price' } = $price;
                        }
                    }
                    
                    elsif (index($url, "staples") != -1){
                        my $link = $1;
                        my $title = $2;
                        my $price = $3;
                        $price =~ s/[A-Z_a-z \$,]+//g;
                        
                        if ($title ne "" and $price ne ""){
                            $save = 1;
                            $single_result{ 'link' } = $link;
                            $single_result{ 'title' } = $title;
                            $single_result{ 'price' } = $price;
                        }
                    }
                    
                    elsif (index($url, "walmart") != -1){
                        my $link = $1;
                        my $title = $2;
                        my $bigprice = $3;
                        my $smallprice = $4;
                        my $rating = $5;
                        my $review = $6;
                        $link = "http://www.walmart.com". $link;
                        my $price = $bigprice . $smallprice;
                        $price =~ s/[A-Z_a-z \$,]+//g;
                        $rating = substr($rating, 0, 3);

                        
                        if ($title ne "" and $price ne ""){
                            $save = 1;
                            $single_result{ 'link' } = $link;
                            $single_result{ 'title' } = $title;
                            $single_result{ 'price' } = $price;
                            $single_result{ 'rating' } = $rating;
                            $single_result{ 'review' } = $review;
                        }
                    }
                    if ($save == 1){
                        # calculate the relevance between the query and the title
                        # We implement a simple weighting scheme, which assigns a weight of 1 
                        # to common words and a weight of 2 to non-common words. The words being weighted are only the ones in the project title. 
                        # All punctuations are removed before the weighting scheme. We did not implement a stemmed version of the program, but think 
                        # that stemmed words will yield better relevance ranking.
                        my %title_vector = ();
                        my $title = $single_result{ 'title' };
                        $title = lc($title);
                        $title =~ s/[[:punct:]]//g;
                        my @title_array = split(/[ \/]/, $title);
                        
                        for my $element ( @title_array ){
                            if (! exists $stoplist_hash{ $element }) {
                                $title_vector{ $element } += 2;
                            }
                            else{
                                $title_vector{ $element } += 1;
                            }
                        }
                        my $relevance = &cosine_sim_a(\%query_vector, \%title_vector);
                        $single_result{ 'relevance' } = $relevance;
                        push @result, \%single_result;
                        
                        #get the rating for each product, each product's rating is from 0 to 5
                        #if the rating is not exist in this website, then we set the rating to 3.
                        if (!exists $single_result{ 'rating' }){
                            $single_result{ 'rating'} = 3;
                        }
                    }
                }
                #print "extract url: " . $url . " finished\n";
                print "total number extracted: " . "$num" . "\n";
                print LOG "extract url " . $url . " finished\n";
                print LOG "total number extracted: " . "$num" . "\n";
            }
        }
        
        #print the result
        print LOG "print the result now\n";
        #sort the result in here
        
        # if it is ranked by price
        # the items with the lowest price is shown first.
        if ($method == 1){
            @result = sort { $a->{'price'} <=> $b->{'price'} } @result;
        }
        
        # if it is ranked by rating
        # the item with the highest rating is displayed first.
        if ($method == 2){
            @result = sort { $b->{'rating'} <=> $a->{'rating'}} @result;
        }
        
        # if it is ranked by relevance
        # the item with the highest relevance (determined by vector space model 
        # similar to assignment 2's) is displayed first.
        elsif ($method == 3){
            @result = sort { $b->{'relevance'} <=> $a->{'relevance'}} @result;
        }
        
        # if it is overall rank
        # The overall rank for an item is the aggregate sum of the 
        # numbers from these two lists. So, an item with a ranking of 1 in the price list and a rank of 3 in the relevance list receives the overall score 
        # of 19 + 17 = 36. 
        elsif ($method == 4){
            my $index = 0;
            @result = sort { $a->{'price'} <=> $b->{'price'} } @result;
            for my $element ( @result ){
                $element->{'score'} += scalar @result - $index;
                ++$index;
            }
            $index = 0;
            @result = sort { $b->{'rating'} <=> $a->{'rating'}} @result;
            for my $element ( @result ){
                $element->{'score'} += scalar @result - $index;
                ++$index;
            }
            $index = 0;
            @result = sort { $b->{'relevance'} <=> $a->{'relevance'}} @result;
            for my $element ( @result ){
                $element->{'score'} += scalar @result - $index;
                ++$index;
            }
            @result = sort { $b->{'score'} <=> $a->{'score'} } @result;
        }
        
        my $number = 1;
        for my $element ( @result )
        {
            print $number . ":\n";
            print RESULT $number . ":\n";
            while (my ($key, $value) = each($element)){
                print $key . ": " . $value . "\n";
                print RESULT $key . ": " . $value . "\n";
            }
            ++$number;
        }
        print "Total results: " . scalar @result . "\n";
        print RESULT "Total results: " . scalar @result . "\n";
        close LOG;
        close RESULT;
    } 
}

##########################################################
##  initialize_configuration
##
##  This function reads the configuration file for the hash of hash
##  datastructure %CFG. This information will be used for following steps.
#############################################################

sub initialize_configuration {
    my $configure_file = shift (@ARGV);
    if (!defined ($configure_file)) {
        print STDERR "You must specify a configuration file\n";
        print STDERR " perl ./metashopper.pl configuration.txt log.txt result.txt\n";
        exit (1);
    }
    
    open CONFIGURE, "configuration.txt" or die $!;
    
    my $classification = undef;
    my @classificiaton_attribute = [];
    my $url = undef;
    my $regex = undef;
    my @attribute_array = [];
    my $line = undef;
    
    while($line = <CONFIGURE>) {
        $classification = $line;
        chomp($classification);
        #print "classification: " . $classification . "\n";
        my $temp_attribute = <CONFIGURE>;
        chomp($temp_attribute);
        @classificiaton_attribute = split (/\s/, $temp_attribute);
        
        #create a new attribute hash
        my %attribute_hash = ();
        my %classification_hash = ();
        
        for (my $i = 0; $i < scalar @classificiaton_attribute; ++$i){
            #print "attribute". $i. ": " . $classificiaton_attribute[$i] . "  ";
            $attribute_hash{ $classificiaton_attribute[$i] } = $i;
        }
        #print "\n";
        
        #store the attribute info into the data structures.
        $classification_hash{ 'attribute' } = {%attribute_hash};
        
        while(defined($line = <CONFIGURE>) and $line ne "\n") {
            #create a url hash and a new attribute hash
            my %url_hash = ();
            my %attribute_hash = ();
            
            $url = $line;
            $url =~ s/[\n]//g;
            chomp($url);
            
            $regex = <CONFIGURE>;
            chomp($regex);
            #print "regex: " . $regex . "\n";
            $url_hash{ 'regex' } = $regex;
            
            my $temp_attribute = <CONFIGURE>;
            chomp($temp_attribute);
            @attribute_array = split (/\s/, $temp_attribute);
            for (my $i = 0; $i < scalar @attribute_array; ++$i){
                #print "attribute". $i. ": " . $attribute_array[$i] . "  ";
                $attribute_hash{ $attribute_array[$i] } = $i
            }
        #   print "\n";
            $url_hash{ 'attriute' } = {%attribute_hash};
            #store the url info into the data structures.
            $classification_hash{ $url } = {%url_hash};
        }
        #store the classification info into the data structures.
        $CFG{ $classification } = {%classification_hash};
        #print "\n";
    }
    close CONFIGURE; 
}

##########################################################
##  initialize_lwp
##
##  This function will initialize the lwp for extracting the 
##  content from the website in the future
#############################################################

sub initialize_lwp {
    $ua = LWP::UserAgent->new;
    
    # Define user agent type
    $ua->agent('Mozilla/8.0');
}

##########################################################
##  initialize_lwp
##
##  This function will reads in the words which is not important for
##  product query from commonwords file for both the document set
##  and the query set. This information will be used in
##  relevance ranking
#############################################################

sub initialize_common_words {
    my $stoplist   = "common_words";
    my $stoplist_fh   = new FileHandle $stoplist  , "r" or croak "Failed $stoplist";
    
    my $line = undef;
    while (defined( $line = <$stoplist_fh> )) {
        chomp $line;
        $stoplist_hash{ $line } = 1;
    }
}

########################################################
## COSINE_SIM_A
## 
## Computes the cosine similarity for two vectors
## represented as associate arrays.
########################################################

sub cosine_sim_a {

    my $vec1 = shift;
    my $vec2 = shift;

    my $num     = 0;
    my $sum_sq1 = 0;
    my $sum_sq2 = 0;

    my @val1 = values %{ $vec1 };
    my @val2 = values %{ $vec2 };

    # determine shortest length vector. This should speed 
    # things up if one vector is considerable longer than
    # the other (i.e. query vector to document vector).

    if ((scalar @val1) > (scalar @val2)) {
        my $tmp  = $vec1;
        $vec1 = $vec2;
        $vec2 = $tmp;
    }

    # calculate the cross product

    my $key = undef;
    my $val = undef;

    while (($key, $val) = each %{ $vec1 }) {
        $num += $val * ($$vec2{ $key } || 0);
    }

    # calculate the sum of squares

    my $term = undef;

    foreach $term (@val1) { $sum_sq1 += $term * $term; }
    foreach $term (@val2) { $sum_sq2 += $term * $term; }

    return ( $num * 1.0 / sqrt( $sum_sq1 * $sum_sq2 ));
}

########################################################
## trim
## 
## remove all the space before, between or after the specific string.
########################################################

sub trim($)
{
    my $string = shift;
    $string=~s/^\s+//g;
    $string=~s/\s+$//g;
    $string=~s/\s+/ /g;
    return $string;
}

