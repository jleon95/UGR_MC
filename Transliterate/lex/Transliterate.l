/*

Transliterate.

Javier León Palomares - 3ºC - 2015/2016

Programa para transliterar japonés escrito con caracteres occidentales a hiragana (ひらがな) o viceversa.
Por defecto parsea un archivo HTML de animelyrics.com en busca de bloques que transliterar.

*/

 /***********************************************************-Declaraciones-***********************************************************/

%{

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void CutExtension(const char previous[], char modified[]); // Recorta la extensión .pdf, .tex o .txt del nombre si la tiene.
void ParseToPlainText(const char * output, const int opth); // Cabecera de la función que guarda en un archivo de texto.
void ParseToTex(const char * output, const int opth); // Cabecera de la función que guarda en un archivo .tex para luego compilarlo a .pdf

int opto = 0; // Control de activación de la opción -o (output). Es necesario que sea global para controlar ciertas acciones de flex.
int optp = 0; // Control de activación de la opción -p (pdf output). También es necesario que sea global.
int with_translation = 0; // Necesario para asegurar la correcta identificación de las etiquetas por la siguiente razón:
							// -Las páginas con romaji + inglés tienen etiquetas distintas para cada uno.
							// -Las páginas sólo con romaji utilizan la misma etiqueta para designar tal contenido que las que utilizan
							//  las otras páginas para designar el inglés.
							// Por tanto, es necesario un mecanismo para saber cuándo la misma etiqueta debe ser analizada (contiene romaji)
							// o ignorada (contiene inglés). Esta variable a 0 indica que nos encontramos ante únicamente romaji sin inglés.

%}

whatever_caps					[A-Z]{2,}
whatever						[a-zA-Z]+
empty_space_out_of_block	[\n\r]+

 /* Estado para transliteración hacia salida estándar o archivo de texto plano.*/
%x T_TO_H
 /* Estado para transliteración inversa hacia salida estándar o archivo de texto plano.*/
%x H_TO_T
 /* Estado para transliteración hacia archivo .tex compilado en .pdf*/
%x T_TO_H_LATEX
 /* Estado para transliteración inversa hacia archivo .tex compilado en .pdf (sólo por completitud, ya que yo no le veo el atractivo).*/
%x H_TO_T_LATEX 

 /*Los estados H_TO_T y H_TO_T_LATEX no se usan al parsear HTML.*/


%%


 /***********************************************************-Reglas-***********************************************************/

 /*==================================Reconocimiento del título de la canción.==================================*/

<INITIAL>"<li>"[^\<].*"</li>"	/*Siempre es el único elemento del archivo dentro de esta etiqueta sin <a href=...> (enlace)*/	{

	char * title = (char *)calloc(yyleng+1, sizeof(char));
	strncpy(title, &yytext[4], yyleng-9); // Guardar el título eliminando la etiqueta de inicio y cierre de elemento de lista.

	if(opto)

		fprintf(yyout, "%s\n\n", title);

	else if(!opto && optp)
		// Para conseguir poner el título de la canción en la cabecera y la portada tengo que hacer esta parte del .tex aquí
		// en vez de en su función correspondiente.
		fprintf(yyout,
				"\\fancyhead[LO]{\\textcolor[rgb]{0.2,0.2,0.9}{%s}}"
				"\\begin{document}\n"
				"\\begin{CJK}{UTF8}{goth}\n\n"
				"\\title{\\Huge %s}\n"
				"\\author{\\footnotesize Made with Transliterate}\n"
				"\\date{\\footnotesize \\copyright\\ 2015 Javier León Palomares}\n"
				"\\maketitle\n"
				"\\newpage\n"
				"\\begin{center}\n"
				"\\noindent\n", title, title);

	free(title);

}

 /*==================================FIN SECCIÓN ANTERIOR==================================*/





 /*==================================Reconocimiento de etiquetas HTML que encapsulen romaji.==================================*/

<INITIAL>{empty_space_out_of_block} /*Evitar que se llene el output de espacio en blanco.*/
<INITIAL>"<td class=romaji NOWRAP><span class=lyrics><dt>Lyrics from Animelyrics.com</dt>"		{ 

	if(!with_translation)

		with_translation++; // Si hay traducción al inglés, siempre se encontrará un contenedor de romaji antes, 
							// por lo que no hay peligro de permitir transliterar traducciones al inglés por error.
	if(optp)

		BEGIN(T_TO_H_LATEX);

	else if(!optp)

		BEGIN(T_TO_H);

} /*Encuentra contenedores en páginas acompañadas de traducción.*/


<INITIAL>"<span class=lyrics><dt>Lyrics from Animelyrics.com</dt>"	{ 

	if(!with_translation){ // Si la canción no tiene traducción al inglés, el contenido a transliterar está dentro de este contenedor.

		if(optp)

			BEGIN(T_TO_H_LATEX);

		else if(!optp)

			BEGIN(T_TO_H);

	}

} /*Encuentra contenedores en páginas no acompañadas de traducción.*/

 /*==================================FIN SECCIÓN ANTERIOR==================================*/





 /*==================================Reconocimiento explícito de ciertos caracteres.==================================*/
 									/*(Lo que no reconozca no lo va a imprimir)*/
<T_TO_H,H_TO_T,T_TO_H_LATEX,H_TO_T_LATEX>" "		{ fprintf(yyout, " "); } /*Reconocer espacios y pintarlos.*/
<T_TO_H,H_TO_T>"\t"									{ fprintf(yyout, "\t"); } /*Reconocer tabuladores y pintarlos.*/
<T_TO_H,H_TO_T>"\n"									{ fprintf(yyout, "\n"); } /*Reconocer saltos de línea normales y pintarlos.*/
<T_TO_H,H_TO_T,T_TO_H_LATEX,H_TO_T_LATEX>"!"		{ fprintf(yyout, "!"); } /*Reconocer signos de exclamación y pintarlos.*/
<T_TO_H,H_TO_T,T_TO_H_LATEX,H_TO_T_LATEX>"?"		{ fprintf(yyout, "?"); } /*Reconocer signos de interrogación y pintarlos.*/
<T_TO_H,T_TO_H_LATEX>"&nbsp;"						{ fprintf(yyout, " "); } /*Reconocer espacios de tal estilo en HTML.*/
<T_TO_H>"<br>"										{ fprintf(yyout, "\n"); } /*Reconocer saltos de línea en HTML.*/
<H_TO_T,H_TO_T_LATEX>{whatever}						{ ECHO; } /*Reconocer todas las letras latinas entre el texto en hiragana (aquí no hay confusión con romaji).*/
<T_TO_H,T_TO_H_LATEX>"</span>"						{ BEGIN(INITIAL); } /*Reconocer el final del contenedor que agrupa los elementos que buscamos.*/
<T_TO_H,T_TO_H_LATEX>{whatever_caps}						{ 

	char * word = (char *)calloc(yyleng+1, sizeof(char));
	strcpy(word, yytext);
	int i, distance = 'a' - 'A';
	
	for(i = 1 ; i < strlen(word) ; i++) // La convención es que si queremos evitar que alguna palabra dentro del bloque sea transformada
										// debemos ponerla en mayúscula. Como una palabra totalmente en mayúscula queda fea, paso todas 
		word[i] += distance;			// las letras excepto la primera a minúscula.

	fprintf(yyout, "%s", word);
	free(word);

} /*Reconocer palabras formadas por mayúsculas (suelen estar en ingĺés).*/

 /*==================================FIN SECCIÓN ANTERIOR==================================*/





 /*==================================Conversión de finales de línea a finales de línea en LaTeX.==================================*/
<T_TO_H_LATEX,H_TO_T_LATEX>"\n"|"<br>"					{ fprintf(yyout, "\\leavevmode\\\\\n"); }

 /*==================================FIN SECCIÓN ANTERIOR==================================*/





 /*==================================Romaji a hiragana.==================================*/
		/*(se usa tanto para output por pantalla y texto como para output en pdf)*/

 /*Consonantes duplicadas.*/
<T_TO_H,T_TO_H_LATEX>kka								{ fprintf(yyout,"っか"); }
<T_TO_H,T_TO_H_LATEX>kkya								{ fprintf(yyout,"っきゃ"); }
<T_TO_H,T_TO_H_LATEX>kke								{ fprintf(yyout,"っけ"); }
<T_TO_H,T_TO_H_LATEX>kki								{ fprintf(yyout,"っき"); }
<T_TO_H,T_TO_H_LATEX>kko								{ fprintf(yyout,"っこ"); }
<T_TO_H,T_TO_H_LATEX>kkō								{ fprintf(yyout,"っこう"); }
<T_TO_H,T_TO_H_LATEX>kkyo								{ fprintf(yyout,"っきょ"); }
<T_TO_H,T_TO_H_LATEX>kkyō								{ fprintf(yyout,"っきょう"); }
<T_TO_H,T_TO_H_LATEX>kku								{ fprintf(yyout,"っく"); }
<T_TO_H,T_TO_H_LATEX>kkū								{ fprintf(yyout,"っくう"); }
<T_TO_H,T_TO_H_LATEX>kkyu								{ fprintf(yyout,"っきゅ"); }
<T_TO_H,T_TO_H_LATEX>kkyū								{ fprintf(yyout,"っきゅう"); }
<T_TO_H,T_TO_H_LATEX>ppa								{ fprintf(yyout,"っぱ"); }
<T_TO_H,T_TO_H_LATEX>ppe								{ fprintf(yyout,"っぺ"); }
<T_TO_H,T_TO_H_LATEX>ppi								{ fprintf(yyout,"っぴ"); }
<T_TO_H,T_TO_H_LATEX>ppo								{ fprintf(yyout,"っぽ"); }
<T_TO_H,T_TO_H_LATEX>ppō								{ fprintf(yyout,"っぽう"); }
<T_TO_H,T_TO_H_LATEX>ppu								{ fprintf(yyout,"っぷ"); }
<T_TO_H,T_TO_H_LATEX>ppū								{ fprintf(yyout,"っぷう"); }
<T_TO_H,T_TO_H_LATEX>ssa								{ fprintf(yyout,"っさ"); }
<T_TO_H,T_TO_H_LATEX>ssha								{ fprintf(yyout,"っしゃ"); }
<T_TO_H,T_TO_H_LATEX>sse								{ fprintf(yyout,"っせ"); }
<T_TO_H,T_TO_H_LATEX>sshi								{ fprintf(yyout,"っし"); }
<T_TO_H,T_TO_H_LATEX>sso								{ fprintf(yyout,"っそ"); }
<T_TO_H,T_TO_H_LATEX>ssō								{ fprintf(yyout,"っそう"); }
<T_TO_H,T_TO_H_LATEX>ssho								{ fprintf(yyout,"っしょ"); }
<T_TO_H,T_TO_H_LATEX>sshō								{ fprintf(yyout,"っしょう"); }
<T_TO_H,T_TO_H_LATEX>ssu								{ fprintf(yyout,"っす"); }
<T_TO_H,T_TO_H_LATEX>ssū								{ fprintf(yyout,"っすう"); }
<T_TO_H,T_TO_H_LATEX>sshu								{ fprintf(yyout,"っしゅ"); }
<T_TO_H,T_TO_H_LATEX>sshū								{ fprintf(yyout,"っしゅう"); }
<T_TO_H,T_TO_H_LATEX>tta								{ fprintf(yyout,"った"); }
<T_TO_H,T_TO_H_LATEX>tte								{ fprintf(yyout,"って"); }
<T_TO_H,T_TO_H_LATEX>(tchi|cchi)						{ fprintf(yyout,"っち"); }
<T_TO_H,T_TO_H_LATEX>tto								{ fprintf(yyout,"っと"); }
<T_TO_H,T_TO_H_LATEX>ttō								{ fprintf(yyout,"っとう"); }
<T_TO_H,T_TO_H_LATEX>ttsu								{ fprintf(yyout,"っつ"); }
<T_TO_H,T_TO_H_LATEX>ttsū								{ fprintf(yyout,"っつう"); }
 /*Vocales.*/
<T_TO_H,T_TO_H_LATEX>(A|a)								{ fprintf(yyout,"あ"); }
<T_TO_H,T_TO_H_LATEX>(E|e)								{ fprintf(yyout,"え"); }
<T_TO_H,T_TO_H_LATEX>(I|i)								{ fprintf(yyout,"い"); }
<T_TO_H,T_TO_H_LATEX>(O|o)								{ fprintf(yyout,"お"); }
<T_TO_H,T_TO_H_LATEX>(Ō|ō)								{ fprintf(yyout,"おう"); }
<T_TO_H,T_TO_H_LATEX>(U|u)								{ fprintf(yyout,"う"); }
<T_TO_H,T_TO_H_LATEX>(Ū|ū)								{ fprintf(yyout,"うう"); }
 /*Sílabas.*/
<T_TO_H,T_TO_H_LATEX>(H|h)a								{ fprintf(yyout,"は"); }
<T_TO_H,T_TO_H_LATEX>(B|b)a								{ fprintf(yyout,"ば"); }
<T_TO_H,T_TO_H_LATEX>(P|p)a								{ fprintf(yyout,"ぱ"); }
<T_TO_H,T_TO_H_LATEX>(H|h)e								{ fprintf(yyout,"へ"); }
<T_TO_H,T_TO_H_LATEX>(B|b)e								{ fprintf(yyout,"べ"); }
<T_TO_H,T_TO_H_LATEX>(P|p)e								{ fprintf(yyout,"ぺ"); }
<T_TO_H,T_TO_H_LATEX>(H|h)i								{ fprintf(yyout,"ひ"); }
<T_TO_H,T_TO_H_LATEX>(B|b)i								{ fprintf(yyout,"び"); }
<T_TO_H,T_TO_H_LATEX>(P|p)i								{ fprintf(yyout,"ぴ"); }
<T_TO_H,T_TO_H_LATEX>(H|h)o								{ fprintf(yyout,"ほ"); }
<T_TO_H,T_TO_H_LATEX>(H|h)ō								{ fprintf(yyout,"ほう"); }
<T_TO_H,T_TO_H_LATEX>(B|b)o								{ fprintf(yyout,"ぼ"); }
<T_TO_H,T_TO_H_LATEX>(B|b)ō								{ fprintf(yyout,"ぼう"); }
<T_TO_H,T_TO_H_LATEX>(P|p)o								{ fprintf(yyout,"ぽ"); }
<T_TO_H,T_TO_H_LATEX>(P|p)ō								{ fprintf(yyout,"ぽう"); }
<T_TO_H,T_TO_H_LATEX>(F|f)u								{ fprintf(yyout,"ふ"); }
<T_TO_H,T_TO_H_LATEX>(F|f)ū								{ fprintf(yyout,"ふう"); }
<T_TO_H,T_TO_H_LATEX>(B|b)u								{ fprintf(yyout,"ぶ"); }
<T_TO_H,T_TO_H_LATEX>(B|b)ū								{ fprintf(yyout,"ぶう"); }
<T_TO_H,T_TO_H_LATEX>(P|p)u								{ fprintf(yyout,"ぷ"); }
<T_TO_H,T_TO_H_LATEX>(P|p)ū								{ fprintf(yyout,"ぷう"); }
<T_TO_H,T_TO_H_LATEX>(K|k)a								{ fprintf(yyout,"か"); }
<T_TO_H,T_TO_H_LATEX>(G|g)a								{ fprintf(yyout,"が"); }
<T_TO_H,T_TO_H_LATEX>(K|k)e								{ fprintf(yyout,"け"); }
<T_TO_H,T_TO_H_LATEX>(G|g)e								{ fprintf(yyout,"げ"); }
<T_TO_H,T_TO_H_LATEX>(K|k)i								{ fprintf(yyout,"き"); }
<T_TO_H,T_TO_H_LATEX>(G|g)i								{ fprintf(yyout,"ぎ"); }
<T_TO_H,T_TO_H_LATEX>(K|k)o								{ fprintf(yyout,"こ"); }
<T_TO_H,T_TO_H_LATEX>(K|k)ō								{ fprintf(yyout,"こう"); }
<T_TO_H,T_TO_H_LATEX>(G|g)o								{ fprintf(yyout,"ご"); }
<T_TO_H,T_TO_H_LATEX>(G|g)ō								{ fprintf(yyout,"ごう"); }
<T_TO_H,T_TO_H_LATEX>(K|k)u								{ fprintf(yyout,"く"); }
<T_TO_H,T_TO_H_LATEX>(K|k)ū								{ fprintf(yyout,"くう"); }
<T_TO_H,T_TO_H_LATEX>(G|g)u								{ fprintf(yyout,"ぐ"); }
<T_TO_H,T_TO_H_LATEX>(G|g)ū								{ fprintf(yyout,"ぐう"); }
<T_TO_H,T_TO_H_LATEX>(M|m)a								{ fprintf(yyout,"ま"); }
<T_TO_H,T_TO_H_LATEX>(M|m)e								{ fprintf(yyout,"め"); }
<T_TO_H,T_TO_H_LATEX>(M|m)i								{ fprintf(yyout,"み"); }
<T_TO_H,T_TO_H_LATEX>(M|m)o								{ fprintf(yyout,"も"); }
<T_TO_H,T_TO_H_LATEX>(M|m)ō								{ fprintf(yyout,"もう"); }
<T_TO_H,T_TO_H_LATEX>(M|m)u								{ fprintf(yyout,"む"); }
<T_TO_H,T_TO_H_LATEX>(M|m)ū								{ fprintf(yyout,"むう"); }
<T_TO_H,T_TO_H_LATEX>(N|n)a								{ fprintf(yyout,"な"); }
<T_TO_H,T_TO_H_LATEX>(N|n)e								{ fprintf(yyout,"ね"); }
<T_TO_H,T_TO_H_LATEX>(N|n)i								{ fprintf(yyout,"に"); }
<T_TO_H,T_TO_H_LATEX>(N|n)o								{ fprintf(yyout,"の"); }
<T_TO_H,T_TO_H_LATEX>(N|n)ō								{ fprintf(yyout,"のう"); }
<T_TO_H,T_TO_H_LATEX>(N|n)u								{ fprintf(yyout,"ぬ"); }
<T_TO_H,T_TO_H_LATEX>(N|n)ū								{ fprintf(yyout,"ぬう"); }
<T_TO_H,T_TO_H_LATEX>(R|r)a								{ fprintf(yyout,"ら"); }
<T_TO_H,T_TO_H_LATEX>(R|r)e								{ fprintf(yyout,"れ"); }
<T_TO_H,T_TO_H_LATEX>(R|r)i								{ fprintf(yyout,"り"); }
<T_TO_H,T_TO_H_LATEX>(R|r)o								{ fprintf(yyout,"ろ"); }
<T_TO_H,T_TO_H_LATEX>(R|r)ō								{ fprintf(yyout,"ろう"); }
<T_TO_H,T_TO_H_LATEX>(R|r)u								{ fprintf(yyout,"る"); }
<T_TO_H,T_TO_H_LATEX>(R|r)ū								{ fprintf(yyout,"るう"); }
<T_TO_H,T_TO_H_LATEX>(S|s)a								{ fprintf(yyout,"さ"); }
<T_TO_H,T_TO_H_LATEX>(Z|z)a								{ fprintf(yyout,"ざ"); }
<T_TO_H,T_TO_H_LATEX>(S|s)e								{ fprintf(yyout,"せ"); }
<T_TO_H,T_TO_H_LATEX>(Z|z)e								{ fprintf(yyout,"ぜ"); }
<T_TO_H,T_TO_H_LATEX>(S|s)hi							{ fprintf(yyout,"し"); }
<T_TO_H,T_TO_H_LATEX>(C|c)hiji							{ fprintf(yyout,"ちぢ"); }
<T_TO_H,T_TO_H_LATEX>(J|j)i								{ fprintf(yyout,"じ"); }
<T_TO_H,T_TO_H_LATEX>(S|s)o								{ fprintf(yyout,"そ"); }
<T_TO_H,T_TO_H_LATEX>(S|s)ō								{ fprintf(yyout,"そう"); }
<T_TO_H,T_TO_H_LATEX>(Z|z)o								{ fprintf(yyout,"ぞ"); }
<T_TO_H,T_TO_H_LATEX>(Z|z)ō								{ fprintf(yyout,"ぞう"); }
<T_TO_H,T_TO_H_LATEX>(S|s)u								{ fprintf(yyout,"す"); }
<T_TO_H,T_TO_H_LATEX>(S|s)ū								{ fprintf(yyout,"すう"); }
<T_TO_H,T_TO_H_LATEX>(T|t)suzu							{ fprintf(yyout,"つづ"); }
<T_TO_H,T_TO_H_LATEX>(T|t)suzū							{ fprintf(yyout,"つづう"); }
<T_TO_H,T_TO_H_LATEX>(Z|z)u								{ fprintf(yyout,"ず"); }
<T_TO_H,T_TO_H_LATEX>(Z|z)ū								{ fprintf(yyout,"ずう"); }
<T_TO_H,T_TO_H_LATEX>(T|t)a								{ fprintf(yyout,"た"); }
<T_TO_H,T_TO_H_LATEX>(D|d)a								{ fprintf(yyout,"だ"); }
<T_TO_H,T_TO_H_LATEX>(T|t)e								{ fprintf(yyout,"て"); }
<T_TO_H,T_TO_H_LATEX>(D|d)e								{ fprintf(yyout,"で"); }
<T_TO_H,T_TO_H_LATEX>(C|c)hi							{ fprintf(yyout,"ち"); }
<T_TO_H,T_TO_H_LATEX>(T|t)o								{ fprintf(yyout,"と"); }
<T_TO_H,T_TO_H_LATEX>(T|t)ō								{ fprintf(yyout,"とう"); }
<T_TO_H,T_TO_H_LATEX>(D|d)o								{ fprintf(yyout,"ど"); }
<T_TO_H,T_TO_H_LATEX>(D|d)ō								{ fprintf(yyout,"どう"); }
<T_TO_H,T_TO_H_LATEX>(T|t)su							{ fprintf(yyout,"つ"); }
<T_TO_H,T_TO_H_LATEX>(T|t)sū							{ fprintf(yyout,"つう"); }
<T_TO_H,T_TO_H_LATEX>(W|w)a								{ fprintf(yyout,"わ"); }
<T_TO_H,T_TO_H_LATEX>(W|w)o								{ fprintf(yyout,"を"); }
<T_TO_H,T_TO_H_LATEX>(Y|y)a								{ fprintf(yyout,"や"); }
<T_TO_H,T_TO_H_LATEX>(Y|y)o								{ fprintf(yyout,"よ"); }
<T_TO_H,T_TO_H_LATEX>(Y|y)ō								{ fprintf(yyout,"よう"); }
<T_TO_H,T_TO_H_LATEX>(Y|y)u								{ fprintf(yyout,"ゆ"); }
<T_TO_H,T_TO_H_LATEX>(Y|y)ū								{ fprintf(yyout,"ゆう"); }
 /*Diptongos.*/
<T_TO_H,T_TO_H_LATEX>(H|h)ya							{ fprintf(yyout,"ひゃ"); }
<T_TO_H,T_TO_H_LATEX>(B|b)ya							{ fprintf(yyout,"びゃ"); }
<T_TO_H,T_TO_H_LATEX>(P|p)ya							{ fprintf(yyout,"ぴゃ"); }
<T_TO_H,T_TO_H_LATEX>(H|h)yo							{ fprintf(yyout,"ひょ"); }
<T_TO_H,T_TO_H_LATEX>(H|h)yō							{ fprintf(yyout,"ひょう"); }
<T_TO_H,T_TO_H_LATEX>(B|b)yo							{ fprintf(yyout,"びょ"); }
<T_TO_H,T_TO_H_LATEX>(B|b)yō							{ fprintf(yyout,"びょう"); }
<T_TO_H,T_TO_H_LATEX>(P|p)yo							{ fprintf(yyout,"ぴょ"); }
<T_TO_H,T_TO_H_LATEX>(P|p)yō							{ fprintf(yyout,"ぴょう"); }
<T_TO_H,T_TO_H_LATEX>(H|h)yu							{ fprintf(yyout,"ひゅ"); }
<T_TO_H,T_TO_H_LATEX>(H|h)yū							{ fprintf(yyout,"ひゅう"); }
<T_TO_H,T_TO_H_LATEX>(B|b)yu							{ fprintf(yyout,"びゅ"); }
<T_TO_H,T_TO_H_LATEX>(B|b)yū							{ fprintf(yyout,"びゅう"); }
<T_TO_H,T_TO_H_LATEX>(P|p)yu							{ fprintf(yyout,"ぴゅ"); }
<T_TO_H,T_TO_H_LATEX>(P|p)yū							{ fprintf(yyout,"ぴゅう"); }
<T_TO_H,T_TO_H_LATEX>(K|k)ya							{ fprintf(yyout,"きゃ"); }
<T_TO_H,T_TO_H_LATEX>(G|g)ya							{ fprintf(yyout,"ぎゃ"); }
<T_TO_H,T_TO_H_LATEX>(K|k)yo							{ fprintf(yyout,"きょ"); }
<T_TO_H,T_TO_H_LATEX>(K|k)yō							{ fprintf(yyout,"きょう"); }
<T_TO_H,T_TO_H_LATEX>(G|g)yo							{ fprintf(yyout,"ぎょ"); }
<T_TO_H,T_TO_H_LATEX>(G|g)yō							{ fprintf(yyout,"ぎょう"); }
<T_TO_H,T_TO_H_LATEX>(K|k)yu							{ fprintf(yyout,"きゅ"); }
<T_TO_H,T_TO_H_LATEX>(K|k)yū							{ fprintf(yyout,"きゅう"); }
<T_TO_H,T_TO_H_LATEX>(G|g)yu							{ fprintf(yyout,"ぎゅ"); }
<T_TO_H,T_TO_H_LATEX>(G|g)yū							{ fprintf(yyout,"ぎゅう"); }
<T_TO_H,T_TO_H_LATEX>(M|m)ya							{ fprintf(yyout,"みゃ"); }
<T_TO_H,T_TO_H_LATEX>(M|m)yo							{ fprintf(yyout,"みょ"); }
<T_TO_H,T_TO_H_LATEX>(M|m)yō							{ fprintf(yyout,"みょう"); }
<T_TO_H,T_TO_H_LATEX>(M|m)yu							{ fprintf(yyout,"みゅ"); }
<T_TO_H,T_TO_H_LATEX>(M|m)yū							{ fprintf(yyout,"みゅう"); }
<T_TO_H,T_TO_H_LATEX>(N|n)ya							{ fprintf(yyout,"にゃ"); }
<T_TO_H,T_TO_H_LATEX>(N|n)yo							{ fprintf(yyout,"にょ"); }
<T_TO_H,T_TO_H_LATEX>(N|n)yō							{ fprintf(yyout,"にょう"); }
<T_TO_H,T_TO_H_LATEX>(N|n)yu							{ fprintf(yyout,"にゅ"); }
<T_TO_H,T_TO_H_LATEX>(N|n)yū							{ fprintf(yyout,"にゅう"); }
<T_TO_H,T_TO_H_LATEX>(R|r)ya							{ fprintf(yyout,"りゃ"); }
<T_TO_H,T_TO_H_LATEX>(R|r)yo							{ fprintf(yyout,"りょ"); }
<T_TO_H,T_TO_H_LATEX>(R|r)yō							{ fprintf(yyout,"りょう"); }
<T_TO_H,T_TO_H_LATEX>(R|r)yu							{ fprintf(yyout,"りゅ"); }
<T_TO_H,T_TO_H_LATEX>(R|r)yū							{ fprintf(yyout,"りゅう"); }
<T_TO_H,T_TO_H_LATEX>(S|s)ha							{ fprintf(yyout,"しゃ"); }
<T_TO_H,T_TO_H_LATEX>(J|j)a								{ fprintf(yyout,"じゃ"); }
<T_TO_H,T_TO_H_LATEX>(S|s)ho							{ fprintf(yyout,"しょ"); }
<T_TO_H,T_TO_H_LATEX>(S|s)hō							{ fprintf(yyout,"しょう"); }
<T_TO_H,T_TO_H_LATEX>(J|j)o								{ fprintf(yyout,"じょ"); }
<T_TO_H,T_TO_H_LATEX>(J|j)ō								{ fprintf(yyout,"じょう"); }
<T_TO_H,T_TO_H_LATEX>(S|s)hu							{ fprintf(yyout,"しゅ"); }
<T_TO_H,T_TO_H_LATEX>(S|s)shū							{ fprintf(yyout,"しゅう"); }
<T_TO_H,T_TO_H_LATEX>(J|j)u								{ fprintf(yyout,"じゅ"); }
<T_TO_H,T_TO_H_LATEX>(J|j)ū								{ fprintf(yyout,"じゅう"); }
<T_TO_H,T_TO_H_LATEX>(C|c)ha							{ fprintf(yyout,"ちゃ"); }
<T_TO_H,T_TO_H_LATEX>(C|c)ho							{ fprintf(yyout,"ちょ"); }
<T_TO_H,T_TO_H_LATEX>(C|c)hō							{ fprintf(yyout,"ちょう"); }
<T_TO_H,T_TO_H_LATEX>(C|c)hu							{ fprintf(yyout,"ちゅ"); }
<T_TO_H,T_TO_H_LATEX>(C|c)hū							{ fprintf(yyout,"ちゅう"); }
 /*N.*/
<T_TO_H,T_TO_H_LATEX>n 									{ fprintf(yyout,"ん"); }
 /*Punto.*/
<T_TO_H,T_TO_H_LATEX>\.									{ fprintf(yyout, "。"); }

 /*==================================FIN SECCIÓN ANTERIOR==================================*/





 /*==================================Hiragana a romaji.==================================*/

 /*Consonantes duplicadas.*/
<H_TO_T,H_TO_T_LATEX>っか								{ fprintf(yyout,"kka"); }
<H_TO_T,H_TO_T_LATEX>っきゃ								{ fprintf(yyout,"kkya"); }
<H_TO_T,H_TO_T_LATEX>っけ								{ fprintf(yyout,"kke"); }
<H_TO_T,H_TO_T_LATEX>っき								{ fprintf(yyout,"kki"); }
<H_TO_T,H_TO_T_LATEX>っこ								{ fprintf(yyout,"kko"); }
<H_TO_T,H_TO_T_LATEX>っきょ								{ fprintf(yyout,"kkyo"); }
<H_TO_T,H_TO_T_LATEX>っく								{ fprintf(yyout,"kku"); }
<H_TO_T,H_TO_T_LATEX>っきゅ								{ fprintf(yyout,"kkyu"); }
<H_TO_T,H_TO_T_LATEX>っぱ								{ fprintf(yyout,"ppa"); }
<H_TO_T,H_TO_T_LATEX>っぺ								{ fprintf(yyout,"ppe"); }
<H_TO_T,H_TO_T_LATEX>っぴ								{ fprintf(yyout,"ppi"); }
<H_TO_T,H_TO_T_LATEX>っぽ								{ fprintf(yyout,"ppo"); }
<H_TO_T,H_TO_T_LATEX>っぷ								{ fprintf(yyout,"ppu"); }
<H_TO_T,H_TO_T_LATEX>っさ								{ fprintf(yyout,"ssa"); }
<H_TO_T,H_TO_T_LATEX>っしゃ								{ fprintf(yyout,"ssha"); }
<H_TO_T,H_TO_T_LATEX>っせ								{ fprintf(yyout,"sse"); }
<H_TO_T,H_TO_T_LATEX>っし								{ fprintf(yyout,"sshi"); }
<H_TO_T,H_TO_T_LATEX>っそ								{ fprintf(yyout,"sso"); }
<H_TO_T,H_TO_T_LATEX>っしょ								{ fprintf(yyout,"ssho"); }
<H_TO_T,H_TO_T_LATEX>っす								{ fprintf(yyout,"ssu"); }
<H_TO_T,H_TO_T_LATEX>っしゅ								{ fprintf(yyout,"sshu"); }
<H_TO_T,H_TO_T_LATEX>った								{ fprintf(yyout,"tta"); }
<H_TO_T,H_TO_T_LATEX>って								{ fprintf(yyout,"tte"); }
<H_TO_T,H_TO_T_LATEX>っち								{ fprintf(yyout,"cchi"); }
<H_TO_T,H_TO_T_LATEX>っと								{ fprintf(yyout,"tto"); }
<H_TO_T,H_TO_T_LATEX>っつ								{ fprintf(yyout,"ttsu"); }
 /*Vocales.*/
<H_TO_T,H_TO_T_LATEX>あ									{ fprintf(yyout,"a"); }
<H_TO_T,H_TO_T_LATEX>え									{ fprintf(yyout,"e"); }
<H_TO_T,H_TO_T_LATEX>い									{ fprintf(yyout,"i"); }
<H_TO_T,H_TO_T_LATEX>お									{ fprintf(yyout,"o"); }
<H_TO_T,H_TO_T_LATEX>う									{ fprintf(yyout,"u"); }
 /*Sílabas.*/
<H_TO_T,H_TO_T_LATEX>は									{ fprintf(yyout,"ha"); }
<H_TO_T,H_TO_T_LATEX>ば									{ fprintf(yyout,"ba"); }
<H_TO_T,H_TO_T_LATEX>ぱ									{ fprintf(yyout,"pa"); }
<H_TO_T,H_TO_T_LATEX>へ									{ fprintf(yyout,"he"); }
<H_TO_T,H_TO_T_LATEX>べ									{ fprintf(yyout,"be"); }
<H_TO_T,H_TO_T_LATEX>ぺ									{ fprintf(yyout,"pe"); }
<H_TO_T,H_TO_T_LATEX>ひ									{ fprintf(yyout,"hi"); }
<H_TO_T,H_TO_T_LATEX>び									{ fprintf(yyout,"bi"); }
<H_TO_T,H_TO_T_LATEX>ぴ									{ fprintf(yyout,"pi"); }
<H_TO_T,H_TO_T_LATEX>ほ									{ fprintf(yyout,"ho"); }
<H_TO_T,H_TO_T_LATEX>ぼ									{ fprintf(yyout,"bo"); }
<H_TO_T,H_TO_T_LATEX>ぽ									{ fprintf(yyout,"po"); }
<H_TO_T,H_TO_T_LATEX>ふ									{ fprintf(yyout,"fu"); }
<H_TO_T,H_TO_T_LATEX>ぶ									{ fprintf(yyout,"bu"); }
<H_TO_T,H_TO_T_LATEX>ぷ									{ fprintf(yyout,"pu"); }
<H_TO_T,H_TO_T_LATEX>か									{ fprintf(yyout,"ka"); }
<H_TO_T,H_TO_T_LATEX>が									{ fprintf(yyout,"ga"); }
<H_TO_T,H_TO_T_LATEX>け									{ fprintf(yyout,"ke"); }
<H_TO_T,H_TO_T_LATEX>げ									{ fprintf(yyout,"ge"); }
<H_TO_T,H_TO_T_LATEX>き									{ fprintf(yyout,"ki"); }
<H_TO_T,H_TO_T_LATEX>ぎ									{ fprintf(yyout,"gi"); }
<H_TO_T,H_TO_T_LATEX>こ									{ fprintf(yyout,"ko"); }
<H_TO_T,H_TO_T_LATEX>ご									{ fprintf(yyout,"go"); }
<H_TO_T,H_TO_T_LATEX>く									{ fprintf(yyout,"ku"); }
<H_TO_T,H_TO_T_LATEX>ぐ									{ fprintf(yyout,"gu"); }
<H_TO_T,H_TO_T_LATEX>ま									{ fprintf(yyout,"ma"); }
<H_TO_T,H_TO_T_LATEX>め									{ fprintf(yyout,"me"); }
<H_TO_T,H_TO_T_LATEX>み									{ fprintf(yyout,"mi"); }
<H_TO_T,H_TO_T_LATEX>も									{ fprintf(yyout,"mo"); }
<H_TO_T,H_TO_T_LATEX>む									{ fprintf(yyout,"mu"); }
<H_TO_T,H_TO_T_LATEX>な									{ fprintf(yyout,"na"); }
<H_TO_T,H_TO_T_LATEX>ね									{ fprintf(yyout,"ne"); }
<H_TO_T,H_TO_T_LATEX>に									{ fprintf(yyout,"ni"); }
<H_TO_T,H_TO_T_LATEX>の									{ fprintf(yyout,"no"); }
<H_TO_T,H_TO_T_LATEX>ぬ									{ fprintf(yyout,"nu"); }
<H_TO_T,H_TO_T_LATEX>ら									{ fprintf(yyout,"ra"); }
<H_TO_T,H_TO_T_LATEX>れ									{ fprintf(yyout,"re"); }
<H_TO_T,H_TO_T_LATEX>り									{ fprintf(yyout,"ri"); }
<H_TO_T,H_TO_T_LATEX>ろ									{ fprintf(yyout,"ro"); }
<H_TO_T,H_TO_T_LATEX>る									{ fprintf(yyout,"ru"); }
<H_TO_T,H_TO_T_LATEX>さ									{ fprintf(yyout,"sa"); }
<H_TO_T,H_TO_T_LATEX>ざ									{ fprintf(yyout,"za"); }
<H_TO_T,H_TO_T_LATEX>せ									{ fprintf(yyout,"se"); }
<H_TO_T,H_TO_T_LATEX>ぜ									{ fprintf(yyout,"ze"); }
<H_TO_T,H_TO_T_LATEX>し									{ fprintf(yyout,"shi"); }
<H_TO_T,H_TO_T_LATEX>じ									{ fprintf(yyout,"ji"); }
<H_TO_T,H_TO_T_LATEX>そ									{ fprintf(yyout,"so"); }
<H_TO_T,H_TO_T_LATEX>ぞ									{ fprintf(yyout,"zo"); }
<H_TO_T,H_TO_T_LATEX>す									{ fprintf(yyout,"su"); }
<H_TO_T,H_TO_T_LATEX>ず									{ fprintf(yyout,"zu"); }
<H_TO_T,H_TO_T_LATEX>た									{ fprintf(yyout,"ta"); }
<H_TO_T,H_TO_T_LATEX>だ									{ fprintf(yyout,"da"); }
<H_TO_T,H_TO_T_LATEX>て									{ fprintf(yyout,"te"); }
<H_TO_T,H_TO_T_LATEX>で									{ fprintf(yyout,"de"); }
<H_TO_T,H_TO_T_LATEX>ち									{ fprintf(yyout,"chi"); }
<H_TO_T,H_TO_T_LATEX>ぢ									{ fprintf(yyout,"ji"); }
<H_TO_T,H_TO_T_LATEX>と									{ fprintf(yyout,"to"); }
<H_TO_T,H_TO_T_LATEX>ど									{ fprintf(yyout,"do"); }
<H_TO_T,H_TO_T_LATEX>つ									{ fprintf(yyout,"tsu"); }
<H_TO_T,H_TO_T_LATEX>づ									{ fprintf(yyout,"zu"); }
<H_TO_T,H_TO_T_LATEX>わ									{ fprintf(yyout,"wa"); }
<H_TO_T,H_TO_T_LATEX>を									{ fprintf(yyout,"wo"); }
<H_TO_T,H_TO_T_LATEX>や									{ fprintf(yyout,"ya"); }
<H_TO_T,H_TO_T_LATEX>よ									{ fprintf(yyout,"yo"); }
<H_TO_T,H_TO_T_LATEX>ゆ									{ fprintf(yyout,"yu"); }
 /*Diptongos.*/
<H_TO_T,H_TO_T_LATEX>ひゃ								{ fprintf(yyout,"hya"); }
<H_TO_T,H_TO_T_LATEX>びゃ								{ fprintf(yyout,"bya"); }
<H_TO_T,H_TO_T_LATEX>ぴゃ								{ fprintf(yyout,"pya"); }
<H_TO_T,H_TO_T_LATEX>ひょ								{ fprintf(yyout,"hyo"); }
<H_TO_T,H_TO_T_LATEX>びょ								{ fprintf(yyout,"byo"); }
<H_TO_T,H_TO_T_LATEX>ぴょ								{ fprintf(yyout,"pyo"); }
<H_TO_T,H_TO_T_LATEX>ひゅ								{ fprintf(yyout,"hyu"); }
<H_TO_T,H_TO_T_LATEX>びゅ								{ fprintf(yyout,"byu"); }
<H_TO_T,H_TO_T_LATEX>ぴゅ								{ fprintf(yyout,"pyu"); }
<H_TO_T,H_TO_T_LATEX>きゃ								{ fprintf(yyout,"kya"); }
<H_TO_T,H_TO_T_LATEX>ぎゃ								{ fprintf(yyout,"gya"); }
<H_TO_T,H_TO_T_LATEX>きょ								{ fprintf(yyout,"kyo"); }
<H_TO_T,H_TO_T_LATEX>ぎょ								{ fprintf(yyout,"gyo"); }
<H_TO_T,H_TO_T_LATEX>きゅ								{ fprintf(yyout,"kyu"); }
<H_TO_T,H_TO_T_LATEX>ぎゅ								{ fprintf(yyout,"gyu"); }
<H_TO_T,H_TO_T_LATEX>みゃ								{ fprintf(yyout,"mya"); }
<H_TO_T,H_TO_T_LATEX>みょ								{ fprintf(yyout,"myo"); }
<H_TO_T,H_TO_T_LATEX>みゅ								{ fprintf(yyout,"myu"); }
<H_TO_T,H_TO_T_LATEX>にゃ								{ fprintf(yyout,"nya"); }
<H_TO_T,H_TO_T_LATEX>にょ								{ fprintf(yyout,"nyo"); }
<H_TO_T,H_TO_T_LATEX>にゅ								{ fprintf(yyout,"nyu"); }
<H_TO_T,H_TO_T_LATEX>りゃ								{ fprintf(yyout,"rya"); }
<H_TO_T,H_TO_T_LATEX>りょ								{ fprintf(yyout,"ryo"); }
<H_TO_T,H_TO_T_LATEX>りゅ								{ fprintf(yyout,"ryu"); }
<H_TO_T,H_TO_T_LATEX>しゃ								{ fprintf(yyout,"sha"); }
<H_TO_T,H_TO_T_LATEX>じゃ								{ fprintf(yyout,"ja"); }
<H_TO_T,H_TO_T_LATEX>しょ								{ fprintf(yyout,"sho"); }
<H_TO_T,H_TO_T_LATEX>じょ								{ fprintf(yyout,"jo"); }
<H_TO_T,H_TO_T_LATEX>しゅ								{ fprintf(yyout,"shu"); }
<H_TO_T,H_TO_T_LATEX>じゅ								{ fprintf(yyout,"ju"); }
<H_TO_T,H_TO_T_LATEX>ちゃ								{ fprintf(yyout,"cha"); }
<H_TO_T,H_TO_T_LATEX>ぢゃ								{ fprintf(yyout,"ja"); }
<H_TO_T,H_TO_T_LATEX>ちょ								{ fprintf(yyout,"cho"); }
<H_TO_T,H_TO_T_LATEX>ぢょ								{ fprintf(yyout,"jo"); }
<H_TO_T,H_TO_T_LATEX>ちゅ								{ fprintf(yyout,"chu"); }
<H_TO_T,H_TO_T_LATEX>ぢゅ								{ fprintf(yyout,"ju"); }
 /*N.*/
<H_TO_T,H_TO_T_LATEX>ん									{ fprintf(yyout,"n"); }
 /*Punto.*/
<H_TO_T,H_TO_T_LATEX>。									{ fprintf(yyout,"."); }

 /*==================================FIN SECCIÓN ANTERIOR==================================*/





 /*==================================Resto de input.==================================*/
<INITIAL,T_TO_H,T_TO_H_LATEX,H_TO_T,H_TO_T_LATEX>. /*No imprime lo que no reconozca*/


 /***********************************************************-Fin Reglas-***********************************************************/




%%





 /***********************************************************-Procedimientos-************************************************************/

int main(int argc, char * argv[]){

	int arg;
	char * output_arg; // Nombre del archivo sobre el que escribe yyout en general.
	char * tex_file; // En caso de argumento -p [nombre de pdf]. 
	int opth = 0; // Control de activación de la opción -h (text to hiragana).
	int optr = 0; // Control de activación de la opción -r (reverse).
	int errflag = 0; // Variable para controlar exclusiones mutuas.

	// Valores por defecto de entrada y salida.
	yyin = stdin;
	yyout = stdout;

	while((arg = getopt(argc, argv, "i:o:p:rh")) != -1)

		switch(arg){

			// Opción de input desde archivo.
			case 'i': yyin = fopen(optarg, "r");

					  if(yyin == NULL){

						  printf("El fichero %s no se puede abrir\n", optarg);
						  exit(-1);

					  }
					  break;

			// Opción de output a pdf (mutuamente excluyente con -o).
			case 'p': if(opto) // Error si se ha activado -o.

						errflag++;

					  else{

					  	optp++;
					  	output_arg = optarg;

					  }
					  break;

			// Opción de output a archivo de texto (mutuamente excluyente con -p).
			case 'o': if(optp) // Error si se ha activado -p.

						errflag++;

					  else{

					  	opto++;
					  	output_arg = optarg;

					  }
					  break;

			// Opción de transliteración inversa (japonés -> caracteres occidentales)-
			case 'r': optr++;
					  break;

			// Opción de transliteración directa desde caracteres occidentales a hiragana.
			case 'h': opth++;
					  break;

			default:  break;

		}

	// Check si ha ocurrido activación simultánea de opciones mutuamente excluyentes.
	if(errflag){

		fprintf(stdout, "Error: opciones -o y -p mutuamente excluyentes.\n");
		exit(-1);

	}

	// Selección del conjunto de reglas a aplicar (reconocimiento HTML romaji -> hiragana por defecto).
	if(opth){

		if(optp)

			BEGIN(T_TO_H_LATEX);

		else

			BEGIN(T_TO_H);

	}

	if(optr){

		if(optp)

			BEGIN(H_TO_T_LATEX);

		else

			BEGIN(H_TO_T);

	}

	// Bloque asociado a la opción -p (pdf output).
	if(optp){

		tex_file = (char *)calloc(strlen(output_arg)+1, sizeof(char));
		CutExtension(output_arg, tex_file); // Recortar extensión .pdf del argumento de -p si la tuviera.
		strcat(tex_file, ".tex"); // Concatenación de la extensión .tex para generar código fuente en LaTeX.		
		ParseToTex(tex_file, opth); // Todo lo necesario para analizar el input y crear un PDF con el resultado.
		free(tex_file);
		
	}

	// Bloque asociado a la opción -o (output en archivo de texto).
	else if(opto){

		ParseToPlainText(output_arg, opth); // Todo lo necesario para analizar el input y crear un archivo de texto plano (.txt) con el resultado.

	} 

	else

		yylex();

	fprintf(yyout,"\n");
	fclose(yyout);
	fclose(yyin);
	free(yytext);

	return 0;

}

// Función para recortar la extensión de un nombre.
void CutExtension(const char previous[], char modified[]){

	// Eliminamos la extensión del nombre (si está) para generar nombres sin extensiones de archivo. 
	if((strstr(previous, ".pdf") != NULL) ||
		(strstr(previous, ".tex") != NULL) ||
		(strstr(previous, ".txt") != NULL)){

		strcpy(modified, previous); // Nombre sin extensión.
		modified[strlen(modified)-4] = '\0';

	}

	else

		strncpy(modified, previous, strlen(previous));

}

// Función para parsear con un archivo de texto plano como destino.
void ParseToPlainText(const char * output, const int opth){

	yyout = fopen(output, "w");

	if(yyout == NULL){

		fprintf(stdout, "El fichero %s no se puede abrir\n", output);
		exit(-2);

	}

	if(opth){

		char * name = (char *)calloc(strlen(output)+1, sizeof(char));
		CutExtension(output, name);
		fprintf(yyout, "%s\n\n", name);
		free(name);

	}

	yylex();

}

// Función para parsear y crear un pdf a partir de un output en .tex
void ParseToTex(const char * output, const int opth){

	pid_t pid;

	yyout = fopen(output, "w");

	if(yyout == NULL){

		fprintf(stdout, "El fichero %s no se puede abrir\n", output);
		exit(-2);

	}

	// Lista de opciones parcial del archivo en LaTeX.
	// Esta parte de la lista de opciones la comparten las transliteraciones a .pdf desde HTML y desde texto plano.
	// Debido a que un par de líneas cambian según desde dónde se lea su contenido, es necesaria una separación.
	// En parsing desde HTML, la cabecera y el título necesitan un texto encontrado dentro del propio archivo HTML
	// por lo que, al encontrarlo, se guardará y se completará el resto de las opciones dentro de la acción de la propia regla.
	// Dicha regla sólo se disparará una vez, por lo que es seguro.
	fprintf(yyout,  "\\documentclass[11pt,a4paper]{article}\n"
				    "\\usepackage{CJKutf8}\n"
				    "\\usepackage{color}\n"
					"\\usepackage{fancyhdr}\n\n"
					"\\pagestyle{fancy}\n"
				    "\\setlength{\\oddsidemargin}{18pt}\n"
					"\\setlength{\\headheight}{14pt}\n"
					"\\setlength{\\textheight}{609pt}\n"
					"\\setlength{\\marginparsep}{11pt}\n"
					"\\setlength{\\footskip}{30pt}\n"
					"\\hoffset = 0pt\n"
					"\\voffset = 0pt\n"
					"\\setlength{\\topmargin}{0pt}\n"
					"\\setlength{\\headsep}{25pt}\n"
					"\\setlength{\\textwidth}{424pt}\n"
					"\\setlength{\\marginparwidth}{54pt}\n"
					"\\setlength{\\marginparpush}{5pt}\n"
					"\\paperwidth = 597pt\n"
					"\\paperheight = 845pt\n\n");

	// Resto de la lista de opciones para parsing no desde HTML.
	// El texto para el título y la cabecera se obtiene a partir del nombre pasado como argumento con -p.
	if(opth){

		char * name = (char *)calloc(strlen(output)+1, sizeof(char));
		CutExtension(output, name);

		fprintf(yyout,  "\\fancyhead[LO]{\\textcolor[rgb]{0.2,0.2,0.9}{%s}}"
						"\\begin{document}\n"
						"\\begin{CJK}{UTF8}{goth}\n\n"
						"\\title{\\Huge %s}\n"
						"\\author{\\footnotesize Made with Transliterate}\n"
						"\\date{\\footnotesize \\copyright\\ 2015 Javier León Palomares}\n"
						"\\maketitle\n"
						"\\newpage\n"
						"\\begin{center}\n"
						"\\noindent\n", name, name);

		free(name);

	}

	yylex();

	// Final del documento.
	fprintf(yyout, "\n\n" "\\end{center}"
					"\n" "\\clearpage\\end{CJK}"
					 "\n" "\\end{document}");

	// Bloque para lanzar el compilador de LaTeX como hijo del proceso actual.
	if((pid = fork()) < 0){

		fprintf(stdout, "Error en fork.\n");
		exit(-3);

	}

	else if(!pid){

		if(execl("/usr/bin/pdflatex", "pdflatex", output, NULL) == -1){

			fprintf(stdout, "Error en exec.\n");
			exit(-4);

		}
	}

	// Bloque para lanzar rm como hijo del proceso actual para borrar los archivos de compilación.
	if((pid = fork()) < 0){

		fprintf(stdout, "Error en fork.\n");
		exit(-3);

	}

	else if(!pid){

		sleep(2);

		if(system("rm -f *.tex *.aux *.log") == -1){

			fprintf(stdout, "Error llamando a rm.\n");
			exit(-5);

		}	
	}
}

/***********************************************************-Fin Procedimientos-************************************************************/