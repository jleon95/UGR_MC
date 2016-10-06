LEX = lex
SRC = src
INCLUDE = include
OBJ = obj
BIN = bin

CXX = gcc
CXXFLAGS = -lfl

all: $(BIN)/Transliterate

$(BIN)/Transliterate: $(OBJ)/Transliterate.o
	@echo "Generando ejecutable."
	@$(CXX) $(OBJ)/Transliterate.o -o $(BIN)/Transliterate $(CXXFLAGS)
	
$(OBJ)/Transliterate.o: $(SRC)/Transliterate.c
	@echo "Generando código objeto."
	@$(CXX) -c $(SRC)/Transliterate.c -o $(OBJ)/Transliterate.o
	
$(SRC)/Transliterate.c: $(LEX)/Transliterate.l
	@echo "Generando código fuente en C."
	@flex -o $(SRC)/Transliterate.c $(LEX)/Transliterate.l
	
clean:
	@echo "Borrando ejecutables, ficheros objeto y código fuente en C."
	@rm -f $(OBJ)/* $(BIN)/* $(SRC)/*