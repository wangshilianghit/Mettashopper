Shiliang Wang and Guannan Ren
Email: wangshiliang@jhu.edu, gren3@jhu.edu
Information Retrieval Final Project
Spring 2013

Project Description: 
For our final project, we decided to implement a MetaShopper application similar to option 4b of the project examples. With our Metashopper application, the user can accomplish a quick and informative search of a query product.
 
At the onset of the project, we gathered inspirations for the functionality of our application from the website "BottomDollar.com." As a team, we discussed which categories to include in our search and from which vendors to pull items of each category. Judging from the amount of time required to retrieve a single page on a specific query from a single vendor, we think that cutting down the number of search results returned would save some time 
during the testing stages.

When implementing information retrieval from the listed vendor sites, we used both post and get methods, and we utilized specific regular expressions to extract specific information for each website,
In addition, we were able to extract the product descriptions for individual items from several websites. The product description was not used during relevance ranking, but does provide useful information for the user.

We included a configuration file named "configuration.txt" with the URLs and the fields we needed to post to each store.

The format of the configuration is as follows:
Category:
List of URLs for the currently supported vendors for the category
Regular expressions for the site
Ordered attributes to be extracted by RegEx

We used a hash->hash->hash data structure for reading the configuration file's data. 

Initially, we planned to implement a basic webpage (with Perl CGI) that will run our Perl application at the backend. However, due to time constraints, we resorted to command line display of the ranked item information. From the command line, the user is first prompted to select the category name (available options include: books, electronics, office supplies, clothing, grocery, and computer). Then, the user is prompted to enter the query string, which can be a single word or multiple words. Lastly, the user must enter the ranking method for the return results. 

Once the results from different vendors are returned, we will be able to choose between ranking by price, by relevance, by rating, or overall ranking. When ranked by price, the items with the lowest price is shown first. When ranked by relevance, the item with the highest relevance (determined by vector space model similar to assignment 2's) is displayed first. We implement a simple weighting scheme, which assigns a weight of 1 to common words and a weight of 2 to non-common words. The words being weighted are only the ones in the project title. All punctuations are removed before the weighting scheme. We did not implement a stemmed version of the program, but think that stemmed words will yield better relevance ranking. 
An overall ranking scheme takes into account the price ranking, the rating ranking, and the word relevance ranking. We assign the number 19 for the first result returned among 20 results for each price, rating, and relevance rankings. Subsequent returned results receive a lower number. The overall rank for an item is the aggregate sum of the numbers from these two lists. So, an item with a ranking of 1 in the price list and a rank of 3 in the relevance list receives the overall score of 19 + 17 = 36.

For the final display of resulting products, we show an unified format across all items within the same category. The information displayed varies by category.

We have tested or project with the following test cases:
Category for electronics:
dell, router, wireless router, Information Retrieval, I want to find a cheap computer 
Category for clothing:
Puma, jeans, Nike shoes, Information Retrieval, I want to find a beautiful jeans 
Category for Office:
staples, microsoft office 2010, Information Retrieval, I want to find a notebook
Category for Books:
Sports, Perl, Information Retrieval, dell computer, I want to find a book about sports
Category for Computer:
Dell, Apple, laptop, Dell computer, Information Retreival, I want to find a dell computer
For All categories:
Dell, computer, basketball, Micorsoft Office 2013, Information Retrieval, Search for fun 

To run the code in the command line, we would input:
perl metashopper.pl configuration.txt log.txt result.txt

The file result.txt returns the final ranked results; log.txt is the debugging output.