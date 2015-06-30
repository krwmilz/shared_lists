#import "DBManager.h"
#import "sqlite3.h"

@interface DBManager()

@property (nonatomic, strong) NSString *documentsDirectory;
@property (nonatomic, strong) NSString *databaseFilename;
@property (nonatomic, strong) NSMutableArray *arrResults;

-(void)copyDatabaseIntoDocumentsDirectory;
-(void)runQuery:(const char *)query isQueryExecutable:(BOOL)queryExecutable;

@end

@implementation DBManager

- (instancetype)initWithDatabaseFilename:(NSString *)dbFilename
{
	self = [super init];

	if (self) {
		// Set the documents directory path to the documentsDirectory property.
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		self.documentsDirectory = [paths objectAtIndex:0];

		// Keep the database filename.
		self.databaseFilename = dbFilename;

		// Copy the database file into the documents directory if necessary.
		[self copyDatabaseIntoDocumentsDirectory];
	}
	return self;
}

- (void)copyDatabaseIntoDocumentsDirectory
{
	// Check if the database file exists in the documents directory.
	NSString *destinationPath = [self.documentsDirectory stringByAppendingPathComponent:self.databaseFilename];
	if (![[NSFileManager defaultManager] fileExistsAtPath:destinationPath]) {
		// The database file does not exist in the documents directory,
		// so copy it from the main bundle now.
		NSString *sourcePath;
		NSError *error;
		sourcePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:self.databaseFilename];
		[[NSFileManager defaultManager] copyItemAtPath:sourcePath toPath:destinationPath error:&error];

		// Check if any error occurred during copying and display it.
		if (error != nil) {
			NSLog(@"%@", [error localizedDescription]);
		}
	}
}

- (void)runQuery:(const char *)query isQueryExecutable:(BOOL)queryExecutable
{
	// Create a sqlite object.
	sqlite3 *sqlite3Database;
    
	// Set the database file path.
	NSString *databasePath;
	databasePath = [self.documentsDirectory stringByAppendingPathComponent:self.databaseFilename];
    
	// Initialize the results array.
	if (self.arrResults != nil) {
		[self.arrResults removeAllObjects];
		self.arrResults = nil;
	}
	self.arrResults = [[NSMutableArray alloc] init];
    
	// Initialize the column names array.
	if (self.arrColumnNames != nil) {
		[self.arrColumnNames removeAllObjects];
		self.arrColumnNames = nil;
	}
	self.arrColumnNames = [[NSMutableArray alloc] init];
    
	// Open the database.
	BOOL openDatabaseResult = sqlite3_open([databasePath UTF8String], &sqlite3Database);
	if (openDatabaseResult != SQLITE_OK) {
		NSLog(@"opening database %@ failed: %s", databasePath,
			sqlite3_errmsg(sqlite3Database));
		return;
	}
    
	// Declare a sqlite3_stmt object in which will be stored the query after
	// having been compiled into a SQLite statement.
	sqlite3_stmt *compiledStatement;
    
	// prepare statement
	BOOL prepareStatementResult = sqlite3_prepare_v2(sqlite3Database, query, -1, &compiledStatement, NULL);
	if (prepareStatementResult != SQLITE_OK) {
		NSLog(@"preparing query %s failed: %s", query,
			sqlite3_errmsg(sqlite3Database));
		sqlite3_close(sqlite3Database);

		return;
	}

	// Check if the query is non-executable.
	if (!queryExecutable) {
		// In this case data must be loaded from the database.
        
		// Declare an array to keep the data for each fetched row.
		NSMutableArray *arrDataRow;
        
		// Loop through the results and add them to the results array
		// row by row.
		while(sqlite3_step(compiledStatement) == SQLITE_ROW) {
			// Initialize the mutable array that will contain the
			// data of a fetched row.
			arrDataRow = [[NSMutableArray alloc] init];
            
			// Get the total number of columns.
			int totalColumns = sqlite3_column_count(compiledStatement);
            
			// Go through all columns and fetch each column data.
			for (int i = 0; i < totalColumns; i++) {
				// Convert the column data to text (characters).
				char *dbDataAsChars = (char *)sqlite3_column_text(compiledStatement, i);

				// If there are contents in the current column
				// (field) then add them to the current row
				// array.
				if (dbDataAsChars != NULL) {
					// Convert the characters to string.
					[arrDataRow addObject:[NSString  stringWithUTF8String:dbDataAsChars]];
				}

				// Keep the current column name.
				if (self.arrColumnNames.count != totalColumns) {
					dbDataAsChars = (char *)sqlite3_column_name(compiledStatement, i);
					[self.arrColumnNames addObject:[NSString stringWithUTF8String:dbDataAsChars]];
				}
			}

			// Store each fetched data row in the results array, but
			// first check if there is actually data.
			if (arrDataRow.count > 0) {
				[self.arrResults addObject:arrDataRow];
			}
		}
	}
	else {
		// executable query (insert, update, ...)

		// Execute the query.
		BOOL executeQueryResults = sqlite3_step(compiledStatement);
		if (executeQueryResults == SQLITE_DONE) {
			// Keep the affected rows.
			self.affectedRows = sqlite3_changes(sqlite3Database);

			// Keep the last inserted row ID.
			self.lastInsertedRowID = sqlite3_last_insert_rowid(sqlite3Database);
		}
		else {
			// If could not execute the query show the error message
			// on the debugger.
			NSLog(@"DB Error: %s", sqlite3_errmsg(sqlite3Database));
		}
	}

	// Release the compiled statement from memory.
	sqlite3_finalize(compiledStatement);

	// Close the database.
	sqlite3_close(sqlite3Database);
}

@end
