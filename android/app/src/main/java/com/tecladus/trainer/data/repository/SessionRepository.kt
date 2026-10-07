package com.tecladus.trainer.data.repository

import com.tecladus.trainer.data.local.TrainerDatabase
import com.tecladus.trainer.domain.model.ActivitySession
import com.tecladus.trainer.domain.model.IntakeEvent
import com.tecladus.trainer.domain.model.TrackPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext

interface SessionRepository {
    val sessions: StateFlow<List<ActivitySession>>
    suspend fun refresh()
    suspend fun save(session: ActivitySession, points: List<TrackPoint>, intakes: List<IntakeEvent>): Long
    suspend fun pointsOf(sessionId: Long): List<TrackPoint>
    suspend fun intakesOf(sessionId: Long): List<IntakeEvent>
    suspend fun delete(sessionId: Long)
    fun byId(sessionId: Long): ActivitySession?
}

class LocalSessionRepository(private val db: TrainerDatabase) : SessionRepository {

    private val _sessions = MutableStateFlow<List<ActivitySession>>(emptyList())
    override val sessions: StateFlow<List<ActivitySession>> = _sessions.asStateFlow()

    override suspend fun refresh() {
        _sessions.value = withContext(Dispatchers.IO) { db.querySessions() }
    }

    override suspend fun save(
        session: ActivitySession,
        points: List<TrackPoint>,
        intakes: List<IntakeEvent>
    ): Long {
        val id = withContext(Dispatchers.IO) { db.insertSession(session, points, intakes) }
        refresh()
        return id
    }

    override suspend fun pointsOf(sessionId: Long): List<TrackPoint> =
        withContext(Dispatchers.IO) { db.queryPoints(sessionId) }

    override suspend fun intakesOf(sessionId: Long): List<IntakeEvent> =
        withContext(Dispatchers.IO) { db.queryIntakes(sessionId) }

    override suspend fun delete(sessionId: Long) {
        withContext(Dispatchers.IO) { db.deleteSession(sessionId) }
        refresh()
    }

    override fun byId(sessionId: Long): ActivitySession? = _sessions.value.firstOrNull { it.id == sessionId }
}
