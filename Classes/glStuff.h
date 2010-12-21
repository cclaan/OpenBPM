// random crap for gl by cc

#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES2/gl.h>

#import <math.h>

void glFlipHorizontal(int w, int h);

void glFlipVertical(int w, int h);

void glRotateBy90CW(int w, int h);

void gliPhoneCoordSystem(int w, int h);

void glProjectionBasic(CGRect rect);

void glBoundingBox(GLfloat w, GLfloat h);

void glBasicDrawing();

void glDrawLineArrow(float startx, float starty, float endx, float endy);
void glDrawLine(float startx, float starty, float endx, float endy);
void glDrawLineFromPoints(CGPoint startp, CGPoint endp );
void glDrawPoint(float xx, float yy, float lw );
///////


static const double pi = 3.14159265358979323846; 
inline static double square(int a) 
{ 
	return a * a; 
} 


void glBasicDrawing() {

	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	glDisable(GL_TEXTURE_2D);	
	
	glDisable(GL_DEPTH_TEST);
	glDisable(GL_BLEND);
	
}


void glBoundingBox(GLfloat w, GLfloat h) {
	
	GLfloat bounding[] = {
		0.0,0.0,
		0.0,0.0,
		0.0,0.0,
		0.0,0.0,
		0.0,0.0
	};
	
	bounding[2] = w;
	bounding[7] = h;
	bounding[4] = w;
	bounding[5] = h;
	
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	glDisable(GL_TEXTURE_2D);
	
	
	glVertexPointer(2, GL_FLOAT, 0, bounding);
	
	glColor4f(1.0, 0.0, 0.0, 1.0);
	glPointSize(12);
	glDrawArrays(GL_POINTS, 0, 1);
	
	glColor4f(1.0, 0.6, 0.2, 1.0);
	glPointSize(7);
	glDrawArrays(GL_POINTS, 0, 4);
	
	glLineWidth(1);
	glColor4f(1.0, 1.0, 1.0, 0.2);
	glDrawArrays(GL_LINE_STRIP, 0, 6);
	
}

void glDrawLineFromPoints(CGPoint startp, CGPoint endp ) {
	glDrawLine(startp.x,startp.y,endp.x,endp.y);
}

void glDrawLine(float startx, float starty, float endx, float endy) {
	
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	glDisable(GL_TEXTURE_2D);
	
	glLineWidth(2);
	//glColor4f(0, 1, 0, 0);
	
	static GLfloat line[] = {
		0.0,20.0,
		320.0,20.0,		
	};
	
	line[0] = startx;
	line[1] = starty;
	line[2] = endx;
	line[3] = endy;
	
	glEnableClientState(GL_VERTEX_ARRAY);
	
	glVertexPointer(2, GL_FLOAT, 0, line);
	glDrawArrays(GL_LINES, 0, 2);
	
	
}

void glDrawPoint(float xx, float yy, float lw ) {
	
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	glDisable(GL_TEXTURE_2D);
	
	glPointSize(lw);
	//glColor4f(0, 0, 1, 0);
	
	static GLfloat line[] = {
		0.0,20.0	
	};
	
	line[0] = xx;
	line[1] = yy;

	glEnableClientState(GL_VERTEX_ARRAY);
	
	glVertexPointer(2, GL_FLOAT, 0, line);
	glDrawArrays(GL_POINTS, 0, 1);
	
	
}

void glDrawLineArrow(float startx, float starty, float endx, float endy) {
	
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	glDisable(GL_TEXTURE_2D);
	
	glLineWidth(3);
	glColor4f(0, 1, 0, 0);
	
	static GLfloat line[] = {
		0.0,20.0,
		320.0,20.0,		
	};
	
	line[0] = startx;
	line[1] = starty;
	line[2] = endx;
	line[3] = endy;
	
	glEnableClientState(GL_VERTEX_ARRAY);
	
	glVertexPointer(2, GL_FLOAT, 0, line);
	glDrawArrays(GL_LINES, 0, 2);
	
	
	CGPoint p,q; 
	p.x = (int) startx;
	p.y = (int) starty;
	q.x = (int) endx;
	q.y = (int) endy;
	double angle;  angle = atan2( (double) p.y - q.y, (double) p.x - q.x ); 
	double hypotenuse; hypotenuse = sqrt( square(p.y - q.y) + square(p.x - q.x) );
	
	/* Here we lengthen the arrow by a factor of three. */ 
	//-q.x = (int) (p.x - 3 * hypotenuse * cos(angle)); 
	//-q.y = (int) (p.y - 3 * hypotenuse * sin(angle)); 
	/* Now we draw the main line of the arrow. */
	
	
	line[0] = p.x;
	line[1] = p.y;
	line[2] = q.x;
	line[3] = q.y;
	
	glVertexPointer(2, GL_FLOAT, 0, line);
	glDrawArrays(GL_LINES, 0, 2);
	
	
	/* Now draw the tips of the arrow.  I do some scaling so that the 
	 * tips look proportional to the main line of the arrow. 
	 */   
	p.x = (int) (q.x + 2 * cos(angle + M_PI / 4)); 
	p.y = (int) (q.y + 2 * sin(angle + M_PI / 4)); 
	//cvLine( frameToDraw, p, q, line_color, line_thickness, CV_AA, 0 ); 
	line[0] = p.x;
	line[1] = p.y;
	line[2] = q.x;
	line[3] = q.y;
	
	glVertexPointer(2, GL_FLOAT, 0, line);
	glDrawArrays(GL_LINES, 0, 2);
	
	p.x = (int) (q.x + 2 * cos(angle - M_PI / 4)); 
	p.y = (int) (q.y + 2 * sin(angle - M_PI / 4)); 
	//cvLine( frameToDraw, p, q, line_color, line_thickness, CV_AA, 0 ); 
	line[0] = p.x;
	line[1] = p.y;
	line[2] = q.x;
	line[3] = q.y;
	
	glVertexPointer(2, GL_FLOAT, 0, line);
	glDrawArrays(GL_LINES, 0, 2);
	
	
}

///

void glProjectionBasic(CGRect rect) {
	
	const GLfloat zNear = 0.01, zFar = 1000.0, fieldOfView = 45.0; 
    GLfloat size; 
    glEnable(GL_DEPTH_TEST);
    glMatrixMode(GL_PROJECTION); 
    size = zNear * tanf(DEGREES_TO_RADIANS(fieldOfView) / 2.0); 
   // CGRect rect = view.bounds; 
    glFrustumf(-size, size, -size / (rect.size.width / rect.size.height), size / 
               (rect.size.width / rect.size.height), zNear, zFar); 
    glViewport(0, 0, rect.size.width, rect.size.height); 
	
}

void gliPhoneCoordSystem(int w, int h) {
	
	glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
	
    glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	
	glOrthof(0, w, 0, h, -1.0f, 1.0f);
	
	glFlipVertical(w, h);
}

void glRotateBy90CW(int w, int h) {
	
	glRotatef(90, 0.0, 0.0, 1.0);
	glTranslatef(0, -w, 0);
	
}

void glFlipVertical(int w, int h) {

	glTranslatef(0., h, 0.);
	glScalef(1., -1., 1.);

}


void glFlipHorizontal(int w, int h) {
	
	glTranslatef(-w, 0, 0.);
	glScalef(-1., 1., 1.);

}